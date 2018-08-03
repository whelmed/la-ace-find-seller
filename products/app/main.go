package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"time"

	"cloud.google.com/go/bigquery"
	"cloud.google.com/go/storage"
	"google.golang.org/api/iterator"
	"google.golang.org/api/option"
)

type item struct {
	Name      string    `json:"name"`
	Option    string    `json:"option"`
	Price     string    `json:"price"`
	Note      string    `json:"note"`
	FileName  string    `json:"fileName"`
	Timestamp time.Time `json:"timestamp"`
}

var serviceAccountFileName string

func init() {
	serviceAccountFileName = os.Getenv("SERVICE_ACCOUNT_FILE_NAME")

	if serviceAccountFileName == "" {
		log.Fatal("missing environment variable SERVICE_ACCOUNT_FILE_NAME")
	}

	if os.Getenv("PROJECT_ID") == "" {
		log.Fatal("missing environment variable PROJECT_ID")
	}

	if os.Getenv("PRODUCT_CACHE_BUCKET") == "" {
		log.Fatal("missing environment variable PRODUCT_CACHE_BUCKET")
	}
}

func productHandler(w http.ResponseWriter, r *http.Request) {
	url, err := cachedProducts(os.Getenv("PRODUCT_CACHE_BUCKET"))

	if err != nil {
		log.Println(err)
		log.Fatal("failed to fetch cached product url")
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"url": url,
	})
}

func cachedProducts(bucketName string) (string, error) {
	ctx := context.Background()

	client, err := storage.NewClient(ctx, option.WithCredentialsFile(serviceAccountFileName))

	if err != nil {
		log.Println(err)
		log.Fatal("client connection error")
	}

	bkt := client.Bucket(bucketName)

	obj := bkt.Object("product_cache.json")

	attrs, err := obj.Attrs(ctx)

	if err == storage.ErrObjectNotExist {
		i, err := json.Marshal(products(bucketName))

		if err != nil {
			log.Println(err)
			return "", err
		}

		return storeObject(bucketName, i), nil
	} else if err != nil {
		log.Println(err)
		return "", err
	}

	// If the cache is older than 5 minutes, refesh it.
	// Yes, this is crude and should be using something such as redis.
	// Though, the Memorystore is beta and the API is unstable.
	if time.Since(attrs.Updated).Minutes() > 5 {
		i, err := json.Marshal(products(bucketName))

		if err != nil {
			log.Println(err)
			return "", err
		}

		return storeObject(bucketName, i), nil
	}

	return fmt.Sprintf("http://storage.googleapis.com/%s/product_cache.json", bucketName), nil
}

func products(bucketName string) []item {
	ctx := context.Background()
	client, err := bigquery.NewClient(ctx, os.Getenv("PROJECT_ID"), option.WithCredentialsFile(serviceAccountFileName))

	if err != nil {
		log.Println(err)
		log.Fatal("cannot create a new bigquery client")
	}

	sql, err := ioutil.ReadFile("products.sql")

	if err != nil {
		log.Println(err)
		log.Fatal("cannot read products.sql")
	}

	q := client.Query(string(sql))

	it, err := q.Read(ctx)

	if err != nil {
		log.Println(err)
		log.Fatal("cannot read query data")
	}

	items := make([]item, 0)
	log.Println(items)
	for {
		var i item
		err := it.Next(&i)

		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Println(err)
			log.Fatal("iterator error")
		}

		i.FileName = fmt.Sprintf("http://storage.googleapis.com/%s/%s", bucketName, i.FileName)
		items = append(items, i)
	}

	log.Println(items)

	return items
}

func storeObject(bucketName string, data []byte) string {
	ctx := context.Background()
	client, err := storage.NewClient(ctx, option.WithCredentialsFile(serviceAccountFileName))
	if err != nil {
		log.Println(err)
		log.Fatal("storage client connection err")
	}

	bkt := client.Bucket(bucketName)

	obj := bkt.Object("product_cache.json")

	// Write something to obj.
	// w implements io.Writer.
	w := obj.NewWriter(ctx)

	// Write some text to obj. This will either create the object or overwrite whatever is there already.

	if _, err := fmt.Fprint(w, string(data)); err != nil {
		log.Println(err)
		log.Fatal("cannot write to storage")
	}

	// Close, just like writing a file.
	if err := w.Close(); err != nil {
		log.Println(err)
		log.Fatal("cannot access attributes")
	}

	obj.Update(ctx, storage.ObjectAttrsToUpdate{
		ContentType: "application/json",
	})

	// Make the object public
	acl := obj.ACL()
	if err := acl.Set(ctx, storage.AllUsers, storage.RoleReader); err != nil {
		log.Println(err)
		log.Fatal("ACL err")
	}

	return fmt.Sprintf("http://storage.googleapis.com/%s/product_cache.json", bucketName)
}

func handlerIcon(w http.ResponseWriter, r *http.Request) {}

func main() {
	http.HandleFunc("/", productHandler)
	http.HandleFunc("/favicon.ico", handlerIcon)
	http.ListenAndServe(":8001", nil)
}

// To run this code locally with the Dockerized GCloud SDK
//docker run --rm -ti --mount src="$(pwd)",target=/code,type=bind --mount src="/User/Ben/go/",target=/go,type=bind -e GOPATH='/go' -p 8001:80 -w /code golang:1.9 go run main.go
