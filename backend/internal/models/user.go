package models

import (
	"time"

	"github.com/google/uuid"
)

// User — сущность пользователя (таблица users).
type User struct {
	ID             uuid.UUID `json:"id"`
	Login          string    `json:"login"`
	PasswordHash   string    `json:"-"` // не отдаём наружу
	FullName       string    `json:"full_name"`
	AvatarURL      *string   `json:"avatar_url,omitempty"`
	Status         string    `json:"status"`
	AdditionalInfo *string   `json:"additional_info,omitempty"`
	Department     *string   `json:"department,omitempty"`
	Position       *string   `json:"position,omitempty"`
	IsActive       bool      `json:"is_active"`
	Role           string    `json:"role"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

// CreateUserInput — данные для создания пользователя.
type CreateUserInput struct {
	Login          string  `json:"login" binding:"required,min=3,max=50"`
	Password       string  `json:"password" binding:"required,min=6"`
	FullName       string  `json:"full_name" binding:"required"`
	AvatarURL      *string `json:"avatar_url"`
	AdditionalInfo *string `json:"additional_info"`
	Department     *string `json:"department"`
	Position       *string `json:"position"`
	Role           string  `json:"role"`
}
