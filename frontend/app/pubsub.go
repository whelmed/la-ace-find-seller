package main

import (
	"context"
	"encoding/json"
	"os"

	"cloud.google.com/go/pubsub"
	"golang.org/x/oauth2/google"
	"google.golang.org/api/option"
	"google.golang.org/appengine"
	"google.golang.org/appengine/log"
)

func publish(ctx context.Context, i interface{}) error {
	creds, err := google.FindDefaultCredentials(ctx, pubsub.ScopePubSub)

	if err != nil {
		log.Debugf(ctx, "error finding default credentials")
	}

	client, err := pubsub.NewClient(ctx, appengine.AppID(ctx), option.WithCredentials(creds))

	if err != nil {
		log.Debugf(ctx, "client connection error")
		return err
	}

	t := client.Topic(os.Getenv("APP_TOPIC"))

	exists, err := t.Exists(ctx)

	if !exists {
		log.Debugf(ctx, "topic named %s not found", os.Getenv("APP_TOPIC"))
		return err
	}

	m := &pubsub.Message{}

	b, err := json.Marshal(i)

	if err != nil {
		log.Debugf(ctx, "marshal to json failed")
		return err
	}

	m.Data = b

	pr := t.Publish(ctx, m) // Publish the message so Cloud Functions can pick it up

	// Blocking call...otherwise app engine gets cranky.
	// At least that's my guess at why the message pubs locally and not on GAE.
	sid, err := pr.Get(ctx)

	if err != nil {
		log.Debugf(ctx, "error publishing to PubSub")
		return err
	}

	log.Debugf(ctx, "server id for pubsub message is %s", sid)

	return nil
}
