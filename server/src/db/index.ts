import Database from "better-sqlite3";
import { readFileSync } from "fs";
import { join } from "path";

// En memoria: para este mockup no hace falta persistir entre reinicios,
// y evita el estado obsoleto entre corridas de la demo.
export const db = new Database(":memory:");
db.pragma("foreign_keys = ON");

const schemaPath = join(__dirname, "schema.sql");
db.exec(readFileSync(schemaPath, "utf-8"));
