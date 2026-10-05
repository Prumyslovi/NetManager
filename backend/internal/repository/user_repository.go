package repository

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"netmanager/internal/models"
)

var (
	ErrUserNotFound      = errors.New("user not found")
	ErrUserAlreadyExists = errors.New("user with this login already exists")
)

type UserRepository struct {
	db *pgxpool.Pool
}

func NewUserRepository(db *pgxpool.Pool) *UserRepository {
	return &UserRepository{db: db}
}

func (r *UserRepository) Create(ctx context.Context, user *models.User) error {
	query := `
		INSERT INTO users (
			login, password_hash, full_name, avatar_url,
			additional_info, department, position, role
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id, status, is_active, created_at, updated_at
	`

	err := r.db.QueryRow(ctx, query,
		user.Login,
		user.PasswordHash,
		user.FullName,
		user.AvatarURL,
		user.AdditionalInfo,
		user.Department,
		user.Position,
		user.Role,
	).Scan(
		&user.ID,
		&user.Status,
		&user.IsActive,
		&user.CreatedAt,
		&user.UpdatedAt,
	)

	if err != nil {
		if strings.Contains(err.Error(), "duplicate key") || strings.Contains(err.Error(), "unique constraint") {
			return ErrUserAlreadyExists
		}
		return fmt.Errorf("create user: %w", err)
	}

	return nil
}

func (r *UserRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	query := `
		SELECT id, login, password_hash, full_name, avatar_url,
		       status, additional_info, department, position,
		       is_active, role, created_at, updated_at
		FROM users
		WHERE id = $1
	`

	var user models.User
	err := r.db.QueryRow(ctx, query, id).Scan(
		&user.ID,
		&user.Login,
		&user.PasswordHash,
		&user.FullName,
		&user.AvatarURL,
		&user.Status,
		&user.AdditionalInfo,
		&user.Department,
		&user.Position,
		&user.IsActive,
		&user.Role,
		&user.CreatedAt,
		&user.UpdatedAt,
	)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrUserNotFound
		}
		return nil, fmt.Errorf("get user by id: %w", err)
	}

	return &user, nil
}

func (r *UserRepository) List(ctx context.Context) ([]models.User, error) {
	query := `
		SELECT id, login, password_hash, full_name, avatar_url,
		       status, additional_info, department, position,
		       is_active, role, created_at, updated_at
		FROM users
		ORDER BY created_at DESC
	`

	rows, err := r.db.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("list users: %w", err)
	}
	defer rows.Close()

	var users []models.User
	for rows.Next() {
		var user models.User
		if err := rows.Scan(
			&user.ID,
			&user.Login,
			&user.PasswordHash,
			&user.FullName,
			&user.AvatarURL,
			&user.Status,
			&user.AdditionalInfo,
			&user.Department,
			&user.Position,
			&user.IsActive,
			&user.Role,
			&user.CreatedAt,
			&user.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan user: %w", err)
		}
		users = append(users, user)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("rows error: %w", err)
	}

	return users, nil
}
