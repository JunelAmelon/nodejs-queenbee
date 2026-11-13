// --- IMPORTS des middlewares ---
import express from "express";
import morgan from "morgan";

const app = express();
const PORT = 3000;

// --- MIDDLEWARES (Intergiciels) ---
app.use(express.json());
app.use(morgan("dev"));

// --- DONNÉES EN MÉMOIRE ---
const hives = [
  { id: "SN-CASA-001", site_id: "SN-CASA", status: "active" },
  { id: "SN-CASA-002", site_id: "SN-CASA", status: "active" },
  { id: "SN-THIE-001", site_id: "SN-THIE", status: "active" },
  { id: "SN-THIE-002", site_id: "SN-THIE", status: "inactive" },
];

const measures = [];

// Vérifie que le serverur est bien en fonctionnement
app.get("/health", (req, res) => {
  res.status(200).json({ status: "ok" });
});


