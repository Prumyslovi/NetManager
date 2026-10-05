package service

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"golang.org/x/crypto/argon2"

	"netmanager/internal/models"
	"netmanager/internal/repository"
)

var ErrInvalidRole = errors.New("invalid role")

type UserService struct {
	repo *repository.UserRepository
}

func NewUserService(repo *repository.UserRepository) *UserService {
	return &UserService{repo: repo}
}

func (s *UserService) Create(ctx context.Context, input models.CreateUserInput) (*models.User, error) {
	role := input.Role
	if role == "" {
		role = "User"
	}
	if role != "Admin" && role != "Developer" && role != "User" {
		return nil, ErrInvalidRole
	}

	user := &models.User{
		Login:          input.Login,
		PasswordHash:   hashPassword(input.Password),
		FullName:       input.FullName,
		AvatarURL:      input.AvatarURL,
		AdditionalInfo: input.AdditionalInfo,
		Department:     input.Department,
		Position:       input.Position,
		Role:           role,
	}

	if err := s.repo.Create(ctx, user); err != nil {
		return nil, err
	}
	return user, nil
}

func (s *UserService) GetByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	return s.repo.GetByID(ctx, id)
}

func (s *UserService) List(ctx context.Context) ([]models.User, error) {
	return s.repo.List(ctx)
}

// Учебный вариант хеширования. Позже сделаем нормальную соль.
func hashPassword(password string) string {
	salt := []byte("netmanager-static-salt-change-me")
	hash := argon2.IDKey([]byte(password), salt, 1, 64*1024, 4, 32)
	return fmt.Sprintf("%x", hash)
}
