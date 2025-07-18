package models

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type ServiceProvider struct {
	ID           primitive.ObjectID `json:"id,omitempty" bson:"_id,omitempty"`
	UserID       primitive.ObjectID `json:"userId" bson:"userId"`
	BusinessName string             `json:"businessName" bson:"businessName"`
	Category     string             `json:"category" bson:"category"`
	ContactInfo  ContactInfo        `json:"contactInfo" bson:"contactInfo"`
	LogoURL      string             `json:"logoUrl,omitempty" bson:"logoUrl,omitempty"`
	ReferralCode string             `json:"referralCode,omitempty" bson:"referralCode,omitempty"`
	CreatedBy    primitive.ObjectID `json:"createdBy" bson:"createdBy"`
	CreatedAt    time.Time          `json:"createdAt" bson:"createdAt"`
	UpdatedAt    time.Time          `json:"updatedAt" bson:"updatedAt"`
	Status       string             `json:"status" bson:"status"` // "pending", "approved", "rejected"
}
