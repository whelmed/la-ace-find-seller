package main

import (
	"fmt"
	"html/template"
	"io"
	"math/rand"
	"net/http"
	"os"

	"github.com/labstack/echo"

	"google.golang.org/appengine"
	"google.golang.org/appengine/log"
	"google.golang.org/appengine/user"
)

var serviceAccountFileName string

func init() {
	serviceAccountFileName = os.Getenv("SERVICE_ACCOUNT_FILE_NAME")
}

func randomString(n int) string {
	var letter = []rune("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

	b := make([]rune, n)
	for i := range b {
		b[i] = letter[rand.Intn(len(letter))]
	}
	return string(b)
}

// Template is the template with renderer for this App Engine app.
type Template struct {
	templates *template.Template
}

// Render processes the template by name, and merges in the data.
func (t *Template) Render(w io.Writer, name string, data interface{}, c echo.Context) error {
	return t.templates.ExecuteTemplate(w, name, data)
}

type item struct {
	Name     string `json:"name" form:"name" query:"name"`
	Option   string `json:"option" form:"option" query:"option"`
	Price    string `json:"price" form:"price" query:"price"`
	Notes    string `json:"notes" form:"notes" query:"notes"`
	Photo    []byte `json:"photo" form:"photo" query:"photo"`
	FileName string `json:"fileName"`
	FileType string `json:"fileType"`
	UserName string `json:"userName"`
}

// EnsureAuthenticated is a second line of verification that the user is authenticated.
// The app.yaml is set to require auth. However, this is to make sure that should that be removed, we're still covered.
func EnsureAuthenticated(next echo.HandlerFunc) echo.HandlerFunc {
	return func(c echo.Context) error {
		// Create a new app engine context from the request.
		ctx := appengine.NewContext(c.Request())
		// Grab the user from the app engine context.
		// The app.yaml requires all users to be authenticated.
		u := user.Current(ctx)

		// Check for an authenticated user. If there isn't one, direct the user to the Google Login
		if u == nil {
			url, err := user.LoginURL(ctx, "/")

			// Did something fail when we tried to get the login URL?
			if err != nil {
				log.Debugf(ctx, err.Error())
				return c.Render(http.StatusInternalServerError, "error.html", map[string]interface{}{
					"error": err.Error,
				})
			}
			// Head to the login url
			return c.Redirect(http.StatusTemporaryRedirect, url)

		}

		return next(c)
	}
}

func uploadHandler(c echo.Context) error {
	// Create a new app engine context from the request.
	ctx := appengine.NewContext(c.Request())
	i := &item{}
	err := c.Bind(i) // For those new to Go this is populating the item named "i" with the values from the request.

	// If we ran into an error binding the values from the posted data, return the error and log it.
	if err != nil {
		log.Debugf(ctx, err.Error())
		return c.Render(http.StatusInternalServerError, "error.html", map[string]interface{}{
			"error": err.Error,
		})
	}

	// Grab the file that was posted.
	file, err := c.FormFile("image")
	if err != nil {
		log.Debugf(ctx, err.Error())
		return c.Render(http.StatusInternalServerError, "error.html", map[string]interface{}{
			"error": err.Error,
		})
	}
	// Open up the file that was uploaded.
	src, err := file.Open()
	if err != nil {
		log.Debugf(ctx, err.Error())
		return c.Render(http.StatusInternalServerError, "error.html", map[string]interface{}{
			"error": err.Error,
		})
	}
	defer src.Close() // Close the file handle after this function runs.

	// Assign the photo field to an empty byte slice of the same size as the uploaded file.
	i.Photo = make([]byte, file.Size)
	_, err = src.Read(i.Photo) // Populate the value of i.Photo with the results of the file.

	// If there was an error reading the file, deal with it here.
	if err != nil {
		log.Debugf(ctx, err.Error())
		return c.Render(http.StatusInternalServerError, "error.html", map[string]interface{}{
			"error": err.Error,
		})
	}

	// We need to set the fileName field.
	// It's sent over to pubsub and used as the file name inside Storage.
	i.FileName = fmt.Sprintf("%s-%s", randomString(15), file.Filename)
	i.UserName = user.Current(ctx).String()
	i.FileType = file.Header.Get("Content-Type")

	// Publish the item stored in the variable named "i" to a PubSub topic.
	if err := publish(ctx, i); err != nil {
		log.Debugf(ctx, err.Error())
		return c.Render(http.StatusInternalServerError, "error.html", map[string]interface{}{
			"error": err.Error,
		})
	}
	// Redirect to the home page.
	return c.Redirect(http.StatusFound, "/")
}

// indexHandler is the code that is executed when someone goes to the homepage, as determined by the root URL of /
func indexHandler(c echo.Context) error {
	// Create a new app engine context from the request.
	ctx := appengine.NewContext(c.Request())
	// The app.yaml requires all users to be authenticated.
	// The EnsureAuthenticated checks to ensure this isn't null.
	u := user.Current(ctx)

	url, err := user.LogoutURL(ctx, "/")

	// Did something fail when we tried to get the logout URL?
	if err != nil {
		log.Debugf(ctx, err.Error())
		return c.Render(http.StatusInternalServerError, "error.html", map[string]interface{}{
			"error": err.Error,
		})
	}

	return c.Render(http.StatusOK, "index.html", map[string]interface{}{
		"fullName":   u.String(),
		"logoutLink": url,
	})
}

func main() {
	e := echo.New()

	t := &Template{
		templates: template.Must(template.ParseGlob("templates/*.html")),
	}

	e.Renderer = t

	e.GET("/", indexHandler, EnsureAuthenticated)
	e.POST("/upload", uploadHandler, EnsureAuthenticated)

	http.Handle("/", e)

	appengine.Main()
}

// To run this code locally with the Dockerized GCloud SDK
//docker run --rm -ti --mount src="$(pwd)",target=/code,type=bind --mount src="/User/Ben/go/",target=/go,type=bind -e GOPATH='/go' -p 8000:8000 -p 8080:8080 --volumes-from gcloud-config google/cloud-sdk dev_appserver.py /code/app.yaml --host=0.0.0.0
