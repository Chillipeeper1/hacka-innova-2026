import { Router } from "express";
import { db } from "../db";

export const demandRouter = Router();

demandRouter.get("/demand/stops", (_req, res) => {
  const rows = db
    .prepare(
      `SELECT stop_id, COUNT(*) as waiting_count
       FROM boarding_signals
       WHERE status = 'waiting' AND stop_id IS NOT NULL
       GROUP BY stop_id`
    )
    .all();
  res.json(rows);
});
