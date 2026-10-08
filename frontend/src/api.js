import axios from 'axios';

// In production this is injected at build/deploy time (see .env files / CI variables)
const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:5001/api';

export const fetchTodos = async () => {
  const res = await axios.get(`${API_BASE_URL}/todos`);
  return res.data;
};

export const createTodo = async (title) => {
  const res = await axios.post(`${API_BASE_URL}/todos`, { title });
  return res.data;
};

export const updateTodo = async (id, payload) => {
  const res = await axios.put(`${API_BASE_URL}/todos/${id}`, payload);
  return res.data;
};

export const deleteTodo = async (id) => {
  const res = await axios.delete(`${API_BASE_URL}/todos/${id}`);
  return res.data;
};
