package services

import (
	"context"
	"strings"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
)

type PushMessage struct {
	Title string
	Body  string
	Data  map[string]string
}

type PushSender interface {
	SendToToken(ctx context.Context, token string, message PushMessage) (string, error)
}

type FirebasePushSender struct {
	client *messaging.Client
}

func NewFirebasePushSender(ctx context.Context, projectID string) (*FirebasePushSender, error) {
	config := &firebase.Config{}
	if strings.TrimSpace(projectID) != "" {
		config.ProjectID = strings.TrimSpace(projectID)
	}
	app, err := firebase.NewApp(ctx, config)
	if err != nil {
		return nil, err
	}
	client, err := app.Messaging(ctx)
	if err != nil {
		return nil, err
	}
	return &FirebasePushSender{client: client}, nil
}

func (s *FirebasePushSender) SendToToken(ctx context.Context, token string, message PushMessage) (string, error) {
	data := map[string]string{}
	for key, value := range message.Data {
		data[key] = value
	}
	return s.client.Send(ctx, &messaging.Message{
		Token: token,
		Notification: &messaging.Notification{
			Title: message.Title,
			Body:  message.Body,
		},
		Data: data,
		Android: &messaging.AndroidConfig{
			Priority: "high",
			Notification: &messaging.AndroidNotification{
				ChannelID: "schooldesk_updates",
			},
		},
		APNS: &messaging.APNSConfig{
			Payload: &messaging.APNSPayload{
				Aps: &messaging.Aps{
					Sound: "default",
				},
			},
		},
	})
}
