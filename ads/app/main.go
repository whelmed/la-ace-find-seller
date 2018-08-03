package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"cloud.google.com/go/spanner"
)

type ad struct {
	AdID          string    `json:"adID"`
	Name          string    `json:"name"`
	Company       string    `json:"company"`
	PromisedViews int64     `json:"promisedViews"`
	TimesViewed   int64     `json:"timesViewed"`
	FileName      string    `json:"fileName"`
	Timestamp     time.Time `json:"timestamp"`
}

func init() {

	if os.Getenv("PROJECT_ID") == "" {
		log.Fatal("missing environment variable PROJECT_ID")
	}

	if os.Getenv("SPANNER_INSTANCE") == "" {
		log.Fatal("missing environment variable SPANNER_INSTANCE")
	}

	if os.Getenv("SPANNER_DATABASE") == "" {
		log.Fatal("missing environment variable SPANNER_DATABASE")
	}

	if os.Getenv("AD_BUCKET") == "" {
		log.Fatal("missing environment variable AD_BUCKET")
	}
}

func randomAd() (*ad, error) {

	ctx := context.Background()
	d := fmt.Sprintf("projects/%s/instances/%s/databases/%s", os.Getenv("PROJECT_ID"), os.Getenv("SPANNER_INSTANCE"), os.Getenv("SPANNER_DATABASE"))
	client, err := spanner.NewClient(ctx, d)

	if err != nil {
		log.Println("cannot create client")
		return nil, err
	}
	defer client.Close()

	// Get a random-ish record.
	txn := client.ReadOnlyTransaction()
	defer txn.Close()

	s := spanner.NewStatement("SELECT AdID FROM ads ORDER BY SHA1(CONCAT(CAST(CURRENT_TIMESTAMP() AS STRING), AdID)) DESC LIMIT 1")
	iter := client.Single().Query(ctx, s)

	var ns spanner.NullString
	var key spanner.Key

	err = iter.Do(func(row *spanner.Row) error {
		return row.Column(0, &ns)
	})

	if err != nil {
		log.Println("iterator error")
		return nil, err
	}

	if ns.Valid {
		key = spanner.Key{ns.StringVal}
	} else {
		fmt.Println("column is NULL")
		return nil, err
	}

	row, err := client.Single().ReadRow(ctx, "ads", key, []string{"AdID", "Company", "PromisedViews", "TimesViewed", "FileName", "Timestamp"})

	if err != nil {
		log.Println("error fetching single row")
		return nil, err
	}

	a := &ad{}

	err = row.ToStruct(a)
	a.FileName = fmt.Sprintf("https://storage.googleapis.com/%s/%s", os.Getenv("AD_BUCKET"), a.FileName)

	if err != nil {
		log.Println("error binding struct")
		return nil, err
	}

	err = updatedUsage(key)

	if err != nil {
		log.Println("error updating value")
		return nil, err
	}

	return a, nil
}

func updatedUsage(key spanner.Key) error {
	ctx := context.Background()
	d := fmt.Sprintf("projects/%s/instances/%s/databases/%s", os.Getenv("PROJECT_ID"), os.Getenv("SPANNER_INSTANCE"), os.Getenv("SPANNER_DATABASE"))
	client, err := spanner.NewClient(ctx, d)

	if err != nil {
		log.Println("error creating client")
		return err
	}
	defer client.Close()

	_, err = client.ReadWriteTransaction(ctx, func(ctx context.Context, txn *spanner.ReadWriteTransaction) error {
		var viewed int64
		row, err := txn.ReadRow(ctx, "ads", key, []string{"TimesViewed"})
		if err != nil {
			log.Println("error reading row")
			return err
		}
		if err := row.Column(0, &viewed); err != nil {
			log.Println("error binding column")
			return err
		}

		viewed++
		m := spanner.Update("ads", []string{"AdID", "TimesViewed"}, []interface{}{key[0], viewed})
		return txn.BufferWrite([]*spanner.Mutation{m})

	})

	if err != nil {
		log.Println("error with transaction")
		return err
	}

	return nil
}

func adHandler(w http.ResponseWriter, r *http.Request) {
	a, err := randomAd()

	if err != nil {
		log.Println(err)
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(a)
}

func handlerIcon(w http.ResponseWriter, r *http.Request) {}

func main() {
	http.HandleFunc("/", adHandler)
	http.HandleFunc("/favicon.ico", handlerIcon)
	http.ListenAndServe(":8002", nil)
}
