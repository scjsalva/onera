import axios from 'axios';

const http = axios.create({
  headers: { Accept: 'application/json' },
});

http.interceptors.request.use((config) => {
  const token = document.querySelector('meta[name="csrf-token"]')?.content;
  if (token) config.headers['X-CSRF-Token'] = token;
  return config;
});

export default http;
