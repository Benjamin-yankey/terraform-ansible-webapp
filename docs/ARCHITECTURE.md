# Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────┐
│           Developer Machine                  │
│  ┌──────────────┐    ┌──────────────┐       │
│  │  Terraform   │───▶│   AWS API    │       │
│  └──────────────┘    └──────────────┘       │
│         │                    │               │
│         │                    ▼               │
│         │            ┌──────────────┐        │
│         │            │  AWS Cloud   │        │
│         │            │ ┌──────────┐ │        │
│         │            │ │   VPC    │ │        │
│         │            │ │ ┌──────┐ │ │        │
│         │            │ │ │ EC2  │ │ │        │
│         │            │ │ │      │ │ │        │
│         │            │ │ └──────┘ │ │        │
│         │            │ └──────────┘ │        │
│         │            └──────────────┘        │
│         ▼                                    │
│  ┌──────────────┐                           │
│  │   Ansible    │                           │
│  └──────────────┘                           │
└─────────────────────────────────────────────┘
```

## Technology Stack

### Infrastructure
- **Terraform**: Infrastructure provisioning
- **Ansible**: Configuration management
- **AWS EC2**: Compute instance
- **Amazon Linux 2023**: Operating system

### Backend
- **Flask**: Python web framework
- **SQLAlchemy**: ORM
- **SQLite**: Database
- **Gunicorn**: WSGI server (production)

### Frontend
- **React**: UI framework
- **JavaScript (ES6+)**: Programming language
- **CSS3**: Styling

### Web Server
- **Nginx**: Reverse proxy and static file server

## Component Interaction

1. **Terraform** provisions AWS infrastructure
2. **Ansible** configures the EC2 instance
3. **Nginx** serves React frontend and proxies API requests
4. **Flask** handles API requests
5. **SQLite** stores application data
