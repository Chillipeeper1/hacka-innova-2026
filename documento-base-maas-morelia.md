# Documento base del proyecto
## Plataforma de Movilidad como Servicio (MaaS) — Zona Metropolitana de Morelia

---

## 1. Contexto y problemática

La Zona Metropolitana de Morelia enfrenta un crecimiento acelerado del parque vehicular en arterias críticas (Periférico/Paseo de la República, salidas a Salamanca, Charo y Pátzcuaro), en un momento de transición hacia proyectos de transporte masivo (Teleférico, Morebús/BRT, reestructuración del transporte público).

El problema central: desconexión entre rutas de transporte colectivo (combis y camiones), falta de certidumbre en tiempos de llegada, y ausencia de una plataforma que permita planificar viajes intermodales combinando caminata, transporte colectivo, ciclovía y, a futuro, teleférico.

**Propuesta de valor diferenciadora**: en lugar de depender únicamente de GPS instalado en las unidades (hoy parcial: la Sedum ya opera un piloto de GPS y videovigilancia en 120-130 combis vía el C5 Michoacán, pero la mayoría de las rutas aún no lo tiene), la plataforma genera señal de demanda a partir de la intención declarada y el comportamiento detectado de los propios usuarios — algo que plataformas como Google Maps o Moovit no pueden hacer bien en un contexto de transporte informal. Esta señal se refuerza donde exista la tarjeta de movilidad del Morebús/teleférico (y las combis que se sumen voluntariamente a ese mismo sistema), cuyo tap confirma el abordaje de forma directa.

---

## 2. Alcance del proyecto

### Incluye
- App móvil (Android/iOS) para pasajeros, con registro de usuario, selección de modos de transporte, planeación de viajes multimodales y visualización en tiempo real.
- App o modo separado para conductores, con transmisión de ubicación.
- Backend con motor de ruteo multimodal, ingestión de datos en tiempo real y capa de estadísticas/IA.
- Módulos de inteligencia artificial: detección de modo de transporte, predicción de ETA, predicción de demanda y detección de anomalías.

### No incluye (fuera de alcance en esta etapa)
- Integración operativa directa con concesionarios de transporte (requiere convenios institucionales, es un proceso paralelo no técnico).
- Venta de boletos o cobro dentro de la app.
- Asistente conversacional tipo chatbot (evaluar en fases muy posteriores).
- Personalización de rutas por ML individual (depende de volumen de datos, ver fases).

---

## 3. Arquitectura general y stack tecnológico

| Capa | Tecnología | Justificación |
|---|---|---|
| Cliente móvil | **Flutter** | Un solo código base para Android/iOS |
| Detección de movimiento en dispositivo | **TensorFlow Lite** (on-device) | Clasifica el modo de transporte sin enviar datos crudos de sensores al servidor |
| Mapas y tiles | **MapLibre GL + tiles propios de OpenStreetMap**, auto-hospedados | Elimina el costo variable por usuario activo mensual (a diferencia de Mapbox); se adoptó antes de cruzar el techo de adopción gratuita, ver sección 4 |
| Backend / API | **TypeScript + NestJS**, en contenedores **Fargate con procesadores Graviton (ARM)** | Estructura modular, soporte nativo de WebSockets y MQTT; Graviton reduce el costo de cómputo sin ningún trade-off relevante para este stack |
| Ingesta en tiempo real | **AWS IoT Core (MQTT)**, con lotes de posición cada **60 segundos** | Diseñado para dispositivos con conectividad intermitente; el intervalo de 60s (ajustado desde 30s) reduce a la mitad el costo de mensajería sin afectar la utilidad del ETA |
| Cola local en el dispositivo | **SQLite** (vía plugin en Flutter) | Permite operar el GPS de forma inmune a la falta de señal |
| Motor de ruteo multimodal | **OpenTripPlanner (OTP)**, en Fargate Graviton | Combina caminata + transporte colectivo + bici + teleférico en una sola consulta |
| Ruteo vial simple / map-matching | **OSRM** | Apoyo para asignar posición GPS a una ruta específica de combi/bus |
| Base de datos principal | **PostgreSQL + PostGIS**, en **Amazon Aurora Serverless v2** (con Database Savings Plan una vez que el patrón de uso esté establecido) | Estándar para datos geoespaciales; escala automáticamente con la demanda variable por hora pico |
| Caché | **Redis (Amazon ElastiCache)** | Caché de ETAs calculados y posiciones recientes |
| Predicción de demanda / ETA / anomalías | Modelos de series de tiempo (ej. Prophet) y regresión, entrenados sobre datos históricos en Postgres | Ejecutados como jobs periódicos, no en tiempo real |
| Infraestructura | **AWS** (IoT Core, ECS/Fargate, API Gateway, Aurora, ElastiCache, NAT Gateway administrado) | Se prefirieron los servicios administrados de AWS sobre alternativas auto-operadas — ver tabla 3.1 |

### 3.1 Decisiones de optimización validadas (mantener vs. cambiar)

Tras un análisis 1 a 1 de cada componente contra su alternativa más barata, considerando el ahorro absoluto en dólares contra el riesgo operativo de que un equipo pequeño administre infraestructura crítica:

| Original | Alternativa evaluada | Veredicto | Razón |
|---|---|---|---|
| Fargate | EC2 reservado/Spot | **Mantener Fargate** | El ahorro (~$120-160/mes a escala) no justifica que el equipo administre parcheo y escalado sin DevOps dedicado |
| x86 | Graviton (ARM) | **Cambiar** | Ahorro (~20%) sin ningún trade-off relevante — Node.js/TypeScript ya es compatible |
| Aurora Serverless v2 | RDS fijo | **Mantener Aurora** | Revertir esto elimina el auto-escalado que fue la razón técnica original de la elección |
| Aurora on-demand | Database Savings Plan | **Cambiar, pero después** | Solo aplica una vez que exista un patrón de uso real de varios meses |
| Lote GPS cada 30s | Lote cada 60s | **Cambiar** | Ahorro (~50% en mensajería) sin pérdida perceptible en la utilidad del ETA |
| AWS IoT Core | Broker MQTT propio | **Mantener IoT Core** | El riesgo de que un equipo chico opere mal alta disponibilidad 24/7 supera el ahorro |
| ElastiCache | Redis auto-hospedado | **Mantener ElastiCache** | Ahorro trivial frente al riesgo de una caché sin failover automático |
| Mapbox | MapLibre + tiles propios OSM | **Cambiar, antes de cruzar el free tier** | Es el único costo que crece sin techo natural conforme aumenta la adopción |
| NAT Gateway | NAT instance propia | **Mantener NAT Gateway** | Ahorro modesto frente a un riesgo real de punto único de falla |
| Logs completos | Retención corta + muestreo | **Cambiar** | Ajuste de configuración, no de arquitectura; ahorro casi gratuito de implementar |

---

## 4. Costos aproximados

Estimaciones basadas en precios públicos vigentes de AWS y proveedores de mapas (2026), ya con las optimizaciones de la sección 3.1 aplicadas.

| Componente | MVP / piloto | Escala ciudad completa (~100k usuarios activos) |
|---|---|---|
| Backend (Fargate, Graviton/ARM) | ~$95 | ~$320 |
| Motor de ruteo (OTP, Graviton) | ~$55 | ~$160 |
| Ingesta GPS (IoT Core, lotes de 60s) | ~$15 | ~$100 |
| Base de datos (Aurora Serverless v2) | ~$180 | ~$325 (con Database Savings Plan) |
| Caché (ElastiCache) | ~$20 | ~$120 |
| Mapas (MapLibre + tiles propios OSM) | ~$30 | ~$150 |
| Infraestructura extra (NAT, ALB, logs optimizados) | ~$75 | ~$160 |
| **Total aproximado** | **~$470 USD/mes (~7,950 MXN)** | **~$1,335 USD/mes (~22,700 MXN)** |

*(tipo de cambio de referencia ~17 MXN/USD, septiembre 2026; precios de infraestructura sujetos a cambio, validar contra la calculadora de precios de AWS antes de comprometerse contractualmente)*

**Notas:**
- El ahorro por optimización es modesto en el MVP (~8% vs. arquitectura sin optimizar) porque la base de datos, el mayor costo fijo, no se optimiza aún (el Database Savings Plan requiere historial de uso). El ahorro es sustancial en escala completa (~30%), impulsado por Graviton, el intervalo de lote de GPS y haber quitado el techo de costo de los mapas antes de que doliera.
- Sostenibilidad: a esta escala, el gasto de infraestructura es comparable al salario de una sola persona del equipo — el reto real del proyecto no es el costo de operar, es el modelo de ingresos (ver sección 7).
- Palanca adicional no reflejada en la tabla: **AWS Activate** y programas equivalentes de otras nubes ofrecen créditos para startups (típicamente $1,000-$100,000 USD) que pueden cubrir 12-24 meses de la factura mientras el proyecto encuentra tracción comercial.

---

## 5. Módulos del sistema

### 5.1 Módulo de usuario y perfil
- Registro/autenticación de pasajeros y conductores (roles distintos).
- Preferencias de transporte (ciclovía sí/no, modos habituales).
- Historial de viajes del usuario (base para estadísticas y, en fase posterior, personalización).

### 5.2 Módulo de detección de modo de transporte
- Geofencing de paradas oficiales (combi, bus, teleférico) y zonas de ciclovía.
- Clasificación de actividad (Human Activity Recognition) vía acelerómetro/giroscopio, ejecutada en el dispositivo.
- Map-matching: cruce de ubicación GPS con el trazado de rutas conocidas para distinguir bus de combi cuando el movimiento por sí solo no es suficiente.
- Confirmación explícita del usuario ("¿vas a abordar aquí?") como respaldo y fuente de entrenamiento inicial del modelo.
- Integración con la tarjeta de movilidad del Morebús y el teleférico (y combis que se sumen voluntariamente al mismo sistema, según ya anunció la Sedum), bajo tres mecanismos que coexisten sin que el pasajero note la diferencia: lector dentro de la unidad (confirma abordaje directo, vehículo conocido), lector en estación de espera cerrada (confirma presencia en la parada; el vehículo se infiere después cruzando con las posiciones GPS, o se queda como demanda de parada si hay ambigüedad), y activación manual o por sensor donde la tarjeta todavía no aplica.
- Detección de descenso (liberación de la parada) mediante retorno del patrón de movimiento a caminata sostenida.

### 5.3 Módulo de ruteo y planeación de viajes
- Cálculo de rutas óptimas multimodales (OpenTripPlanner).
- Visualización de transbordos, tiempos estimados por tramo.
- Opción de mostrar solo el modo de transporte seleccionado por el usuario o el panorama completo.

### 5.4 Módulo de tiempo real
- Recepción de posiciones GPS de unidades (conductores) y de señales de demanda (pasajeros en espera).
- Reordenamiento por timestamp generado en el dispositivo (no por orden de llegada al servidor), para reconstruir la ruta real pese a la sincronización por lotes.
- Cálculo y publicación de ETA por parada.

### 5.5 Módulo de estadísticas y demanda
- Conteo agregado y anonimizado de personas en espera por parada/horario.
- Flujo histórico por ruta, insumo para decisiones de asignación de unidades.
- Panel para actores institucionales (municipio, concesionarios) — superficie de producto distinta a la app de pasajero, y base del modelo de negocio principal (ver sección 7).
- Calificaciones de conductor y reportes de incidencias agregados (módulo 5.9), como insumo adicional de calidad de servicio.

### 5.6 Módulo de inteligencia artificial
1. **Detección de modo de transporte** (HAR + map-matching) — descrito en 5.2, es la pieza fundacional de la que dependen las demás.
2. **Predicción de ETA**: modelo entrenado con datos históricos por ruta/hora, más preciso que un cálculo de distancia entre velocidad promedio.
3. **Predicción de demanda por parada/horario**: modelo de series de tiempo que anticipa picos de demanda, no solo los reporta después de ocurridos.
4. **Detección de anomalías**: identifica cuando una ruta tarda significativamente más de lo usual (posible bloqueo/incidente) y puede alertar a otros usuarios de forma preventiva.

### 5.7 Módulo de conductor
- App o modo independiente, con transmisión de ubicación en segundo plano.
- Vista detallada de tiempos y ocupación estimada de su unidad.

### 5.8 Módulo de notificaciones
- Prompts de confirmación de abordaje (con lógica de reducción de fatiga: solo la primera vez en cada parada nueva, después el sistema aprende el patrón habitual del usuario).
- Alertas de ETA y de anomalías detectadas en la ruta.

### 5.9 Módulo de calificación de conductor y reporte de incidencias
- Calificación de 1 a 5 al conductor al término del viaje, con la unidad atribuida automáticamente cuando el mecanismo de abordaje ya la determina (tap dentro de la unidad), o por proximidad calculada en el propio dispositivo — nunca en el servidor, mismo principio de privacidad que el módulo 5.2 — cuando no. Si tampoco así hay certeza, la calificación simplemente no se ofrece para ese viaje.
- Reporte de incidencias categorizado (seguridad, acoso, conducción temeraria, condición del vehículo, unidad que no llegó, otro), con nivel de severidad y seguimiento por estado (pendiente/revisado/resuelto).
- Ambos alimentan el panel institucional (5.5) como insumo de calidad para concesionarios y Sedum — a diferencia de un modelo tipo Uber, el pasajero no elige a su conductor, así que el valor no es ayudar a elegir sino identificar unidades o conductores con quejas recurrentes.

---

## 6. Estrategia de datos para entrenamiento de IA

Los tres modelos de la sección 5.6 (ETA, demanda, anomalías) no se pueden entrenar con un dataset externo listo — dependen fundamentalmente de datos operativos específicos de Morelia. La estrategia se divide en dos etapas:

### 6.1 Arranque (antes de tener volumen propio)
- **Estudios oficiales ya existentes**: Morelia cuenta con un PIMUS (Plan Integral de Movilidad Urbana Sustentable) elaborado por la SCOP del Gobierno del Estado de Michoacán, y un estudio de demanda financiado por FONADIN para el Sistema Integrado de Transporte Público. Vale la pena una solicitud de información pública o acercamiento institucional para acceder a estos datos antes de recolectar desde cero.
- **Recolección manual de campo**: un equipo pequeño recorriendo las rutas clave (Periférico, salidas a Charo/Pátzcuaro/Salamanca) con el propio teléfono, generando una línea base de tiempos de traslado por corredor y hora.
- **APIs de mapas comerciales como proxy**: Google Distance Matrix o HERE, con su capa de tráfico típico, como aproximación inicial del tiempo de recorrido vial (no específico de combi, pero útil para calibrar).

### 6.2 Fuente permanente (una vez en operación)
El propio módulo de detección de modo de transporte (5.2) es simultáneamente la tubería de datos de entrenamiento: cada confirmación de abordaje/descenso genera un registro de ETA real; cada "sí voy a usar este medio" alimenta el modelo de demanda. Por esto, la Fase 1 usa ruteo basado en reglas (ver sección 9) — para darle tiempo a esta fuente, más valiosa y específica de Morelia, a acumularse antes de depender de ella. Donde exista la tarjeta de movilidad (Morebús, teleférico y combis adheridas), los eventos de tap son una fuente todavía más confiable que la confirmación manual, al ser una confirmación física del abordaje y no una intención declarada.

---

## 7. Modelo de negocio

### 7.1 Por qué el modelo es institucional y no de suscripción

MaaS Global, creador de la app Whim y origen del concepto "MaaS" como suscripción B2C que agrega todos los modos de transporte, recaudó más de €149 millones y operó en cinco países, pero se declaró en bancarrota en marzo de 2024 tras pérdidas sostenidas (€9.3M de pérdida sobre €3.8M de facturación en 2022). El problema fue estructural: un agregador de "MaaS completo" debe pagarle a cada operador real (taxi, transporte público, renta de auto) a tarifa casi completa, mientras vende una suscripción empaquetada lo bastante barata para competir con tener auto propio — el margen es demasiado delgado para escalar, y sería aún más difícil en Morelia, donde la tarifa de combi (~10-12 pesos) deja casi ningún margen que capturar, y la oferta son miles de concesionarios informales en vez de un puñado de empresas negociables.

Este proyecto evita ese error porque **nunca se convierte en el intermediario financiero que le paga a cada operador de transporte** — se mantiene como capa de información y ruteo (el producto sí es "MaaS"), mientras el negocio se sostiene con el gobierno como cliente institucional (sección 7.2), no con una suscripción agregadora al usuario final.

El panel de estadísticas de flujo y demanda (módulo 5.5) es el activo que sostiene este modelo: SCOP ya tiene un PIMUS vigente y un estudio de demanda pagado por FONADIN, exactamente el tipo de actor que hoy no tiene datos de flujo en tiempo real y podría valorarlos.

Esta alineación institucional se refuerza más: la Sedum (la dependencia que opera Morebús y el teleférico) ya anunció que las combis podrán integrarse voluntariamente al mismo sistema de tarjeta de prepago, y ya tiene un piloto de 120-130 unidades con GPS y videovigilancia conectado al C5 Michoacán. La plataforma no necesita construir infraestructura de cobro ni de monitoreo — puede conectarse a la que el gobierno ya está desplegando.

### 7.2 Estructura del contrato con gobierno

- **Costo operativo transparente**: pass-through del gasto real de infraestructura (sección 4), con factura de AWS/APIs auditable por el gobierno.
- **Tarifa de mantenimiento fija**, definida por niveles de servicio (SLA) — ej. soporte en horario hábil con respuesta en 24h, frente a un nivel crítico con soporte 24/7 y respuesta en 2h — nunca como porcentaje del gasto de infraestructura, para no premiar gastar más.
- **Licenciamiento como SaaS**, reteniendo la propiedad del software (no venta ni transferencia), permitiendo licenciar la misma plataforma a otras ciudades mexicanas con el mismo problema. Se recomienda incluir una cláusula de **escrow de código fuente** (depósito con un tercero neutral, accesible por el gobierno si la empresa incumple o desaparece) como punto medio razonable entre licenciar y transferir propiedad.
- **Descuento por ingresos secundarios**: conforme crezcan los ingresos complementarios (datos agregados, publicidad — nunca el núcleo del financiamiento), se acredita un descuento sobre la tarifa de mantenimiento del año siguiente, con:
  - **Tope máximo** (ej. 20-30% de la tarifa de mantenimiento), para nunca incentivar sacrificar anonimización o saturar de anuncios solo por bajar el precio.
  - **Fórmula de cálculo publicada en el contrato**, no negociada discrecionalmente cada año.
  - **Revisión anual** (no mensual), alineada al ejercicio fiscal del gobierno.

Este ajuste mantiene la relación entre pago y costo real de operar el servicio — la definición misma de "as a Service" — mientras comparte el éxito de los ingresos secundarios con quien contrató la plataforma.

**Riesgos no técnicos a considerar**: los presupuestos municipales/estatales se aprueban anualmente y los periodos municipales en México son de 3 años, por lo que el pago recurrente depende de que el gasto en movilidad se siga asignando cada ejercicio fiscal; dependiendo del monto y la entidad, puede aplicar ley de adquisiciones que exija licitación en vez de negociación directa (validar con asesoría legal especializada en contratación pública).

---

## 8. Limitantes y riesgos a considerar

- **Precisión de GPS urbano**: 5-15 metros típico, insuficiente por sí solo para distinguir con certeza total el abordaje de una unidad específica; de ahí la necesidad de combinar sensores de movimiento y confirmación del usuario.
- **Arranque en frío del ML personalizado**: con pocos usuarios activos, las recomendaciones individualizadas no tendrán datos suficientes para ser útiles; se recomienda posponerlas a una fase posterior.
- **Sesgo de muestra en estadísticas de flujo**: al inicio solo se captura a quienes tienen la app instalada y activa, un subconjunto de los usuarios reales de transporte colectivo — válido para tendencias relativas, no como censo completo.
- **Dependencia de adopción para el efecto de red**: entre más usuarios reporten intención de uso, más útil es la señal de demanda; la utilidad del sistema crece con la base de usuarios.
- **GPS oficial en unidades, todavía parcial**: la Sedum ya opera un piloto de GPS y videovigilancia en 120-130 combis (rutas Rosa, Roja y Gris) vía el C5 Michoacán, pero la mayoría de las rutas aún no lo tiene — mientras eso no se generalice, la ubicación de esas unidades seguirá dependiendo de inferencia por usuarios a bordo.
- **Dependencia de un acuerdo de datos externo**: la integración con la tarjeta de movilidad depende de que Sedum (o quien opere el sistema de cobro) comparta los eventos de tap vía API — no es una decisión que el equipo pueda resolver solo con desarrollo interno.
- **Consentimiento adicional para vincular la tarjeta**: asociar una tarjeta de movilidad con identidad gubernamental a la cuenta de la app es más sensible que el resto del consentimiento de ubicación — requiere un consentimiento explícito y separado, y la posibilidad de desvincularla en cualquier momento.
- **Excepción consciente a la anonimización**: a diferencia del resto de las estadísticas agregadas, los reportes de incidencias (5.9) sí deben poder rastrearse al usuario que los generó, para permitir seguimiento por parte de concesionarios o Sedum.
- **Consentimiento y protección de datos**: la recolección de ubicación continua y patrones de traslado exige un aviso de privacidad y contrato de condiciones conforme a la LFPDPPP, con anonimización de los datos usados en estadísticas agregadas.
- **Conectividad intermitente**: aunque el diseño offline-first mitiga la falta de señal, sigue existiendo una ventana de retraso entre que ocurre un evento y que el sistema lo recibe.
- **Ciclo presupuestal y político**: el modelo de ingreso núcleo depende de que un gobierno municipal/estatal mantenga el gasto de movilidad asignado cada ejercicio fiscal, con el riesgo adicional de cambios de administración cada 3 años.

---

## 9. Alcance por fases

### Fase 1 — MVP
- Registro de usuario, selección de modos de transporte.
- Geofencing de paradas + confirmación manual de abordaje/descenso (sin clasificación automática por sensores todavía).
- Motor de ruteo multimodal con OpenTripPlanner, basado en reglas (no ML todavía).
- Mapa con ubicación de conductores.
- Aviso de privacidad y contrato de condiciones.

### Fase 2
- Clasificación automática de modo de transporte (HAR on-device + map-matching).
- Integración con eventos de tap de la tarjeta de movilidad (Morebús/teleférico/combis adheridas), sujeta a acuerdo de datos con Sedum — depende de su cronograma externo, no solo del desarrollo interno.
- Calificación de conductor y reporte de incidencias, con atribución de unidad resuelta por proximidad calculada en el dispositivo cuando el mecanismo de abordaje no la determina directamente.
- Estadísticas de flujo agregadas y anonimizadas, con panel institucional (base del modelo de negocio, sección 7).
- Predicción de ETA basada en históricos.

### Fase 3
- Predicción de demanda por parada/horario.
- Detección de anomalías en rutas.
- Personalización de rutas por usuario (una vez que exista volumen suficiente de datos históricos).

---

## 10. Próximos pasos sugeridos

1. Definir y documentar el aviso de privacidad / contrato de condiciones antes de iniciar la recolección de cualquier dato de ubicación.
2. Mapear el catálogo inicial de rutas y paradas oficiales de combi/bus (insumo indispensable para el geofencing y el motor de ruteo).
3. Definir el esquema de base de datos en PostGIS (rutas, paradas, historial de posiciones) con índices espaciotemporales desde el diseño inicial.
4. Construir el MVP de Fase 1 con confirmación manual antes de invertir en los modelos de ML de fases posteriores.
5. Explorar acercamiento con el municipio y concesionarios para eventual instalación de GPS oficial en unidades, en paralelo al desarrollo técnico.
6. Formalizar la estructura del contrato con gobierno (tarifa de mantenimiento por SLA, cláusula de escrow, fórmula de descuento por ingresos secundarios) antes de la propuesta comercial formal.
7. Solicitar acceso al PIMUS y al estudio de demanda de FONADIN vía transparencia o acercamiento institucional directo con SCOP.
8. Explorar un acuerdo de datos con la Sedum (operadora de Morebús, el teleférico y del piloto de modernización de combis con el C5) para acceder a los eventos de tap de la tarjeta de movilidad.
