import cors from "cors";
import express from "express";
import { createServer } from "http";
import { Server } from "socket.io";
import "./db";
import { seed } from "./db/seed";
import { boardingSignalsRouter } from "./routes/boardingSignals";
import { cardTapsRouter } from "./routes/cardTaps";
import { demandRouter } from "./routes/demand";
import { incidentsRouter } from "./routes/incidents";
import { journeysRouter } from "./routes/journeys";
import { routesRouter } from "./routes/routes";
import { stopsRouter } from "./routes/stops";
import { tripsRouter } from "./routes/trips";
import { usersRouter } from "./routes/users";
import { attachIo } from "./sockets/emit";
import { registerSocketHandlers } from "./sockets";

seed();

const PORT = process.env.PORT ? Number(process.env.PORT) : 3001;

const app = express();
app.use(cors());
app.use(express.json());
app.use(routesRouter);
app.use(stopsRouter);
app.use(journeysRouter);
app.use(usersRouter);
app.use(boardingSignalsRouter);
app.use(demandRouter);
app.use(cardTapsRouter);
app.use(tripsRouter);
app.use(incidentsRouter);

const httpServer = createServer(app);
const io = new Server(httpServer, { cors: { origin: "*" } });
attachIo(io);
registerSocketHandlers(io);

httpServer.listen(PORT, () => {
  console.log(`MaaS Morelia mock server escuchando en http://localhost:${PORT}`);
});
