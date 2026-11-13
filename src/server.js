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

// Lister et filtrer les ruches
app.get("/api/hives", (req, res) => {
  const { site_id } = req.query;

  // On vérifie que site_id est bien fourni ET non vide
  if (site_id && site_id.trim() !== "") {
    // On filtre les ruches par site_id
    const filteredHives = hives.filter((hive) => hive.site_id === site_id);
    return res.status(200).json(filteredHives);
  }

  res.status(200).json(hives);
});

//Récuperer une seule ruche par son id
app.get("/api/hives/:id", (req, res) => {
  const hive = hives.find((h) => h.id === req.params.id);

  if (!hive) {
    return res.status(404).json({ error: `Ruche ${req.params.id} introuvable` });
  }

  res.status(200).json(hive);
});
