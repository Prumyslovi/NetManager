package handlers

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

type HealthHandler struct {
	DB    *pgxpool.Pool
	Redis *redis.Client
}

func NewHealthHandler(db *pgxpool.Pool, rdb *redis.Client) *HealthHandler {
	return &HealthHandler{
		DB:    db,
		Redis: rdb,
	}
}

func (h *HealthHandler) Health(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
	defer cancel()

	status := gin.H{
		"status":   "ok",
		"postgres": "ok",
		"redis":    "ok",
	}
	httpStatus := http.StatusOK

	// Проверка PostgreSQL
	if err := h.DB.Ping(ctx); err != nil {
		status["postgres"] = "error: " + err.Error()
		status["status"] = "degraded"
		httpStatus = http.StatusServiceUnavailable
	}

	// Проверка Redis
	if err := h.Redis.Ping(ctx).Err(); err != nil {
		status["redis"] = "error: " + err.Error()
		status["status"] = "degraded"
		httpStatus = http.StatusServiceUnavailable
	}

	c.JSON(httpStatus, status)
}
