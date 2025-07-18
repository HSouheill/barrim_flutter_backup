package models

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type Wholesaler struct {
	ID               primitive.ObjectID   `json:"id,omitempty" bson:"_id,omitempty"`
	UserID           primitive.ObjectID   `json:"userId" bson:"userId"`
	BusinessName     string               `json:"businessName" bson:"businessName"`
	Phone            string               `json:"phone" bson:"phone"`
	AdditionalPhones []string             `json:"additionalPhones,omitempty" bson:"additionalPhones,omitempty"`
	AdditionalEmails []string             `json:"additionalEmails,omitempty" bson:"additionalEmails,omitempty"`
	Category         string               `json:"category" bson:"category"`
	SubCategory      string               `json:"subCategory,omitempty" bson:"subCategory,omitempty"`
	ReferralCode     string               `json:"referralCode,omitempty" bson:"referralCode,omitempty"`
	Referrals        []primitive.ObjectID `json:"referrals,omitempty" bson:"referrals,omitempty"`
	Points           int                  `json:"points" bson:"points"`
	ContactInfo      ContactInfo          `json:"contactInfo" bson:"contactInfo"`
	SocialMedia      SocialMedia          `json:"socialMedia,omitempty" bson:"socialMedia,omitempty"`
	LogoURL          string               `json:"logoUrl,omitempty" bson:"logoUrl,omitempty"`
	Balance          float64              `json:"balance" bson:"balance"`
	Branches         []Branch             `json:"branches,omitempty" bson:"branches,omitempty"`
	CreatedBy        primitive.ObjectID   `json:"createdBy" bson:"createdBy"`
	CreatedAt        time.Time            `json:"createdAt" bson:"createdAt"`
	UpdatedAt        time.Time            `json:"updatedAt" bson:"updatedAt"`
	Status           string               `json:"status" bson:"status"` // "pending", "approved", "rejected"
}
