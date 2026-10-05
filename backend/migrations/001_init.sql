[29.09.2026 12:21] Кирилл Примесь: -- ======================
-- РАСШИРЕНИЯ
-- ======================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ======================
-- 1. НАСТРОЙКИ ОРГАНИЗАЦИИ
-- ======================
CREATE TABLE organization_settings (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    timezone                TEXT NOT NULL DEFAULT 'Europe/Moscow',
    work_days               INTEGER[] NOT NULL DEFAULT '{1,2,3,4,5}',
    work_start              TIME NOT NULL DEFAULT '08:00',
    work_end                TIME NOT NULL DEFAULT '16:30',
    lunch_duration_minutes  INTEGER NOT NULL DEFAULT 30 CHECK (lunch_duration_minutes >= 0),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE holidays (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date        DATE NOT NULL UNIQUE,
    name        TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ======================
-- 2. ПОЛЬЗОВАТЕЛИ
-- ======================
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    login           TEXT NOT NULL UNIQUE,
    password_hash   TEXT NOT NULL,
    full_name       TEXT NOT NULL,
    avatar_url      TEXT,
    status          TEXT NOT NULL DEFAULT 'offline'
                        CHECK (status IN ('online', 'busy', 'away', 'offline')),
    additional_info TEXT,
    department      TEXT,
    position        TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    role            TEXT NOT NULL DEFAULT 'User'
                        CHECK (role IN ('Admin', 'Developer', 'User')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_users_is_active ON users (is_active);
CREATE INDEX idx_users_role ON users (role);

-- ======================
-- 3. ЗАДАЧИ
-- ======================
CREATE TABLE tasks (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title           TEXT NOT NULL,
    description     TEXT,
    priority        TEXT NOT NULL DEFAULT 'unset'
                        CHECK (priority IN ('unset', 'low', 'medium', 'high', 'critical')),
    status          TEXT NOT NULL DEFAULT 'planned'
                        CHECK (status IN ('planned', 'in_progress', 'under_review', 'rejected', 'completed', 'failed')),
    planned_hours   NUMERIC(8,1) CHECK (planned_hours IS NULL OR planned_hours >= 0),
    is_hidden       BOOLEAN NOT NULL DEFAULT false,
    created_by      UUID NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_tasks_status ON tasks (status);
CREATE INDEX idx_tasks_priority ON tasks (priority);
CREATE INDEX idx_tasks_is_hidden ON tasks (is_hidden);
CREATE INDEX idx_tasks_created_by ON tasks (created_by);
CREATE INDEX idx_tasks_created_at ON tasks (created_at);

-- Ответственные за задачу
CREATE TABLE task_assignees (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id     UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id),
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_current  BOOLEAN NOT NULL DEFAULT true,
    UNIQUE (task_id, user_id)
);

CREATE INDEX idx_task_assignees_task ON task_assignees (task_id);
CREATE INDEX idx_task_assignees_user ON task_assignees (user_id);

-- Предшественники
CREATE TABLE task_predecessors (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id                 UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    predecessor_task_id     UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    requires_completion     BOOLEAN NOT NULL DEFAULT true,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (task_id, predecessor_task_id),
    CHECK (task_id <> predecessor_task_id)
);

CREATE INDEX idx_task_predecessors_task ON task_predecessors (task_id);
CREATE INDEX idx_task_predecessors_pred ON task_predecessors (predecessor_task_id);

-- История изменений задачи
CREATE TABLE task_change_history (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id     UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    changed_by  UUID NOT NULL REFERENCES users(id),
    field_name  TEXT NOT NULL,
    old_value   TEXT,
    new_value   TEXT,
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_task_change_history_task ON task_change_history (task_id);
CREATE INDEX idx_task_change_history_at ON task_change_history (changed_at);

-- Комментарии к задачам
CREATE TABLE task_comments (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id     UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id),
    content     TEXT NOT NULL CHECK (length(trim(content)) > 0),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_task_comments_task ON task_comments (task_id);
CREATE INDEX idx_task_comments_user ON task_comments (user_id);
CREATE INDEX idx_task_comments_created_at ON task_comments (created_at);

-- Сверхурочная работа
CREATE TABLE overtime_entries (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id             UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id             UUID NOT NULL REFERENCES users(id),
    work_date           DATE NOT NULL,
    started_at          TIME NOT NULL,
    ended_at            TIME NOT NULL,
    duration_minutes    INTEGER NOT NULL CHECK (duration_minutes > 0),
    reason              TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (ended_at > started_at)
);

CREATE INDEX idx_overtime_task ON overtime_entries (task_id);
CREATE INDEX idx_overtime_user ON overtime_entries (user_id);
CREATE INDEX idx_overtime_date ON overtime_entries (work_date);

-- ======================
-- 4. РЕГУЛЯРНЫЕ ЗАДАЧИ
-- ======================
CREATE TABLE regular_tasks (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title               TEXT NOT NULL,
    description         TEXT,
    priority            TEXT NOT NULL DEFAULT 'unset'
                            CHECK (priority IN ('unset', 'low', 'medium', 'high', 'critical')),
    status              TEXT NOT NULL DEFAULT 'planned'
                            CHECK (status IN ('planned', 'in_progress', 'under_review', 'rejected', 'completed', 'failed')),
    planned_hours       NUMERIC(8,1) CHECK (planned_hours IS NULL OR planned_hours >= 0),
    recurrence_type     TEXT NOT NULL
                            CHECK (recurrence_type IN ('week', 'month', 'year', 'custom_date')),
    recurrence_value    TEXT,
    next_date           DATE NOT NULL,
    attachment_url      TEXT,
    is_completed        BOOLEAN NOT NULL DEFAULT false,
    created_by          UUID NOT NULL REFERENCES users(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_regular_tasks_next_date ON regular_tasks (next_date);
CREATE INDEX idx_regular_tasks_is_completed ON regular_tasks (is_completed);

CREATE TABLE regular_task_assignees (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    regular_task_id     UUID NOT NULL REFERENCES regular_tasks(id) ON DELETE CASCADE,
    user_id             UUID NOT NULL REFERENCES users(id),
    assigned_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (regular_task_id, user_id)
);

CREATE INDEX idx_regular_task_assignees_task ON regular_task_assignees (regular_task_id);
[29.09.2026 12:21] Кирилл Примесь: -- ======================
-- 5. ИНЦИДЕНТЫ
-- ======================
CREATE TABLE incidents (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title           TEXT NOT NULL,
    description     TEXT,
    recorded_by     UUID NOT NULL REFERENCES users(id),
    started_at      TIMESTAMPTZ NOT NULL,
    ended_at        TIMESTAMPTZ,
    solution        TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (ended_at IS NULL OR ended_at >= started_at)
);

CREATE INDEX idx_incidents_started_at ON incidents (started_at);
CREATE INDEX idx_incidents_recorded_by ON incidents (recorded_by);

CREATE TABLE incident_affected (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id     UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
    affected_type   TEXT NOT NULL
                        CHECK (affected_type IN ('internet', 'electricity', 'equipment', 'user', 'organization')),
    affected_id     UUID,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_incident_affected_incident ON incident_affected (incident_id);
CREATE INDEX idx_incident_affected_type ON incident_affected (affected_type);

-- ======================
-- 6. МЕРОПРИЯТИЯ
-- ======================
CREATE TABLE calendar_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title           TEXT NOT NULL,
    description     TEXT,
    event_type      TEXT NOT NULL
                        CHECK (event_type IN ('meeting', 'training', 'inspection', 'audit', 'business_trip', 'other')),
    custom_type     TEXT,
    start_at        TIMESTAMPTZ NOT NULL,
    end_at          TIMESTAMPTZ NOT NULL,
    created_by      UUID NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (end_at >= start_at)
);

CREATE INDEX idx_calendar_events_start ON calendar_events (start_at);
CREATE INDEX idx_calendar_events_type ON calendar_events (event_type);

CREATE TABLE calendar_event_participants (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id    UUID NOT NULL REFERENCES calendar_events(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (event_id, user_id)
);

CREATE INDEX idx_calendar_event_participants_event ON calendar_event_participants (event_id);

-- ======================
-- 7. ДОКУМЕНТЫ
-- ======================
CREATE TABLE documents (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title           TEXT NOT NULL,
    content_type    TEXT NOT NULL
                        CHECK (content_type IN ('markdown', 'pdf', 'table', 'image')),
    created_by      UUID NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE document_versions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id     UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    content         BYTEA NOT NULL,
    version_number  INTEGER NOT NULL CHECK (version_number > 0),
    changed_by      UUID NOT NULL REFERENCES users(id),
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    comment         TEXT,
    UNIQUE (document_id, version_number)
);

CREATE INDEX idx_document_versions_document ON document_versions (document_id);

CREATE TABLE document_access (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id     UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    user_id         UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_document_access_document ON document_access (document_id);

CREATE TABLE task_documents (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id         UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    document_id     UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (task_id, document_id)
);

-- ======================
-- 8. ЗАМЕТКИ
-- ======================
CREATE TABLE notes (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content     TEXT NOT NULL,
    remind_at   TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_notes_user ON notes (user_id);
CREATE INDEX idx_notes_remind_at ON notes (remind_at) WHERE remind_at IS NOT NULL;

-- ======================
-- 9. VAULT
-- ======================
CREATE TABLE vault_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title           TEXT NOT NULL,
    data_encrypted  BYTEA NOT NULL,
    created_by      UUID NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_vault_items_created_by ON vault_items (created_by);

-- ======================
-- 10. АКТИВЫ
-- ======================
CREATE TABLE assets (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type        TEXT NOT NULL
                    CHECK (type IN ('computer', 'server', 'printer', 'network_device', 'other')),
    name        TEXT NOT NULL,
    data        JSONB NOT NULL DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_assets_type ON assets (type);
CREATE INDEX idx_assets_data ON assets USING GIN (data);

CREATE TABLE asset_relations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_asset_id   UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    to_asset_id     UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    relation_type   TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (from_asset_id <> to_asset_id)
);

CREATE INDEX idx_asset_relations_from ON asset_relations (from_asset_id);
CREATE INDEX idx_asset_relations_to ON asset_relations (to_asset_id);

-- ======================
-- 11. МОНИТОРИНГ
-- ======================
CREATE TABLE monitoring_targets (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL,
    target          TEXT NOT NULL,
    check_type      TEXT NOT NULL
                        CHECK (check_type IN ('http', 'tcp', 'ping')),
    port            INTEGER CHECK (port IS NULL OR (port > 0 AND port <= 65535)),
    last_status     TEXT CHECK (last_status IN ('up', 'down')),
    last_check_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE monitoring_metrics (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    target_id       UUID NOT NULL REFERENCES monitoring_targets(id) ON DELETE CASCADE,
    metric_type     TEXT NOT NULL
                        CHECK (metric_type IN ('temperature', 'disk', 'ram', 'cpu')),
    value           NUMERIC NOT NULL,
    recorded_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_monitoring_metrics_target ON monitoring_metrics (target_id);
CREATE INDEX idx_monitoring_metrics_recorded ON monitoring_metrics (recorded_at);

-- ======================
-- 12. AUDIT LOG
-- ======================
CREATE TABLE audit_logs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id  TEXT NOT NULL,
    user_id     UUID REFERENCES users(id),
    action      TEXT NOT NULL,
    entity      TEXT NOT NULL,
    entity_id   UUID,
    ip          TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_logs_request_id ON audit_logs (request_id);
CREATE INDEX idx_audit_logs_user ON audit_logs (user_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs (created_at);
CREATE INDEX idx_audit_logs_entity ON audit_logs (entity, entity_id);
[29.09.2026 12:21] Кирилл Примесь: -- ======================
-- 13. НАСТРОЙКИ TELEGRAM-УВЕДОМЛЕНИЙ
-- ======================
CREATE TABLE telegram_notification_settings (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_type  TEXT NOT NULL,
    is_enabled  BOOLEAN NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, event_type)
);

CREATE INDEX idx_telegram_settings_user ON telegram_notification_settings (user_id);