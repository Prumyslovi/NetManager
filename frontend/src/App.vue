<script setup lang="ts">
import { ref, onMounted } from 'vue'

interface User {
  id: string
  login: string
  full_name: string
  role: string
  status: string
  is_active: boolean
  created_at: string
}

const users = ref<User[]>([])
const loading = ref(false)
const error = ref('')

const form = ref({
  login: '',
  password: '',
  full_name: '',
  role: 'User',
})

const API = 'http://localhost:8080/api'

async function loadUsers() {
  loading.value = true
  error.value = ''
  try {
    const res = await fetch(`${API}/users`)
    if (!res.ok) throw new Error('Не удалось загрузить пользователей')
    users.value = await res.json()
  } catch (e: any) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}

async function createUser() {
  error.value = ''
  try {
    const res = await fetch(`${API}/users`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(form.value),
    })
    if (!res.ok) {
      const data = await res.json()
      throw new Error(data.error || 'Ошибка создания')
    }
    form.value = { login: '', password: '', full_name: '', role: 'User' }
    await loadUsers()
  } catch (e: any) {
    error.value = e.message
  }
}

onMounted(loadUsers)
</script>

<template>
  <div class="stack" style="max-width: 48rem; margin: 0 auto; padding: 2rem 1rem;">
    <h1 class="page-title">NetManager — Пользователи</h1>

    <div class="card stack">
      <h2 class="section-title">Создать пользователя</h2>

      <div class="form-grid">
        <input v-model="form.login" class="input" placeholder="Логин" />
        <input v-model="form.password" type="password" class="input" placeholder="Пароль" />
        <input v-model="form.full_name" class="input" placeholder="ФИО" />
        <select v-model="form.role" class="input">
          <option value="User">User</option>
          <option value="Developer">Developer</option>
          <option value="Admin">Admin</option>
        </select>
      </div>

      <div>
        <button class="btn" @click="createUser">Создать</button>
      </div>
    </div>

    <div v-if="error" class="alert alert-danger">{{ error }}</div>

    <div class="card">
      <div class="row" style="margin-bottom: 1rem;">
        <h2 class="section-title" style="margin: 0;">Список пользователей</h2>
        <button class="btn btn-secondary" @click="loadUsers">Обновить</button>
      </div>

      <div v-if="loading" style="color: var(--color-muted);">Загрузка...</div>

      <table v-else class="table">
        <thead>
          <tr>
            <th>Логин</th>
            <th>ФИО</th>
            <th>Роль</th>
            <th>Статус</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="u in users" :key="u.id">
            <td>{{ u.login }}</td>
            <td>{{ u.full_name }}</td>
            <td>{{ u.role }}</td>
            <td>
              <span class="badge" :class="u.is_active ? 'badge-success' : 'badge-muted'">
                {{ u.is_active ? 'Активен' : 'Неактивен' }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>

      <p v-if="!loading && users.length === 0" style="color: var(--color-muted); margin-top: 1rem;">
        Пользователей пока нет
      </p>
    </div>
  </div>
</template>