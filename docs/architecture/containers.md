# Container Diagram

The container diagram shows the high-level technology choices and how the major pieces of the HiveR system communicate.

## Diagram

```mermaid
C4Container
    title Container Diagram for HiveR

    Person(employee, "Employee", "A registered employee")
    Person(manager, "Manager", "A manager")
    Person(admin, "Admin", "Company owner")

    System_Ext(iot, "IoT Devices", "IoT beacons")
    System_Ext(sns, "AWS SNS", "Notifications")

    Container_Boundary(hiver, "HiveR System") {
        Container(mobile, "Mobile App", "Mobile Application", "Employee-facing mobile app")
        Container(webapp, "Web App", "Web Application", "Management interface for managers and admins")

        Container_Boundary(backend, "Backend Services") {
            Container(main, "Main Service", "NestJS", "Core service handling user management and orchestration")
            Container(presence, "Presence Service", "NestJS", "Manages employee presence tracking")
            Container(tasks, "Tasks Service", "NestJS", "Handles task management workflows")
            Container(bus, "Message Bus", "Kafka", "Event bus for async communication")

            ContainerDb(mainDb, "Main Database", "PostgreSQL", "Stores user and company data")
            ContainerDb(presenceDb, "Presence Database", "PostgreSQL", "Stores presence records")
            ContainerDb(tasksDb, "Tasks Database", "PostgreSQL", "Stores task data")
        }
    }

    Rel(employee, mobile, "Uses")
    Rel(manager, webapp, "Manages workforce using")
    Rel(admin, webapp, "Administrates using")

    Rel(mobile, iot, "Prompts")
    Rel(iot, mobile, "Responds")

    Rel(mobile, main, "Sends requests to")
    Rel(webapp, main, "Sends events to")

    Rel(main, bus, "Publishes events to")
    Rel(main, mainDb, "Reads from and writes to")

    Rel(bus, presence, "Delivers events to")
    Rel(bus, tasks, "Delivers events to")

    Rel(presence, presenceDb, "Writes to")
    Rel(tasks, tasksDb, "Writes to")

    Rel(main, sns, "Sends notifications via")
    Rel(sns, employee, "Sends push notifications to")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## Containers

### Backend
The backend is composed of multiple microservices and shared infrastructure:

- **Main Service** (NestJS): Core service handling user management and orchestration
- **Presence Microservice** (NestJS): Manages employee presence tracking
- **Tasks Microservice** (NestJS): Handles task management workflows
- **Message Bus** (Kafka): Event bus for asynchronous communication
- **Main Database** (PostgreSQL): Stores user data and core system information
- **Presence Database** (PostgreSQL): Stores presence records
- **Tasks Database** (PostgreSQL): Stores task data

### Mobile App
Employee-facing mobile application that:
- Connects to the backend services
- Interacts with IoT devices
- Receives push notifications

### Web App
Browser-based application for managers and administrators that:
- Provides management interface
- Connects to the main backend service
- Sends events through the system

## Communication Patterns

### Synchronous
- Mobile app → Backend (REST/GraphQL)
- Web app → Main Service (REST/GraphQL)

### Asynchronous (Event-Driven)
- Main Service → Message Bus → Microservices
- Microservices → Message Bus (event publishing)
- Backend → AWS SNS (notifications)

## Data Flow

1. Web app sends events to the Main Service
2. Main Service publishes events to the Kafka message bus
3. Microservices (Presence, Tasks) subscribe to relevant events
4. Each microservice processes events and updates its own database
5. Notification events are sent to AWS SNS
6. AWS SNS delivers emails and push notifications to users

---

Next: [Component Diagram](components.md)
