import axios from "axios";

const api = axios.create({
  baseURL: "/api"
});

export const getBots = () => api.get("/bots").then((res) => res.data);

export const getConversation = (botId) =>
  api.get(`/bots/${botId}/conversation`).then((res) => res.data);

export const sendMessage = (botId, mensaje) =>
  api.post(`/bots/${botId}/message`, { mensaje }).then((res) => res.data);

export const clearConversation = (botId) =>
  api.delete(`/bots/${botId}/conversation`);

export default api;
