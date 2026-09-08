import { Router } from "express";
import { db } from "../db";

export const usersRouter = Router();

usersRouter.post("/users", (req, res) => {
  const { name, role } = req.body;
  if (!name || !["passenger", "driver"].includes(role)) {
    res.status(400).json({ error: "name y role ('passenger'|'driver') son requeridos" });
    return;
  }
  const result = db.prepare("INSERT INTO users (name, role) VALUES (?, ?)").run(name, role);
  res.status(201).json({ id: result.lastInsertRowid, name, role });
});
