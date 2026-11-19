import React from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
import { AndroidApp } from "./AndroidApp";
import "./style.css";
import './canvas.css';
createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    {new URLSearchParams(location.search).has("android") ? (
      <AndroidApp />
    ) : (
      <App />
    )}
  </React.StrictMode>,
);
