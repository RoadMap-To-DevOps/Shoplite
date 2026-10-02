# Shoplite

Shoplite is a sample Node.js web application deployed using AWS infrastructure and GitHub Actions CI/CD.

The project demonstrates a DevOps workflow including:

- Git and GitHub branching
- Pull requests and code review
- GitHub Actions CI
- Automated testing
- AWS VPC networking
- Public and private subnets
- NAT Gateway
- Bastion host
- Nginx reverse proxy
- Private EC2 application server
- Automated deployment
- Release management
- Health checks and rollback

---

## Project Structure

```text
Shoplite/
├── .github/
│   └── workflows/
│       └── ci.yml
│
├── app/
│   ├── package.json
│   ├── package-lock.json
│   ├── server.js
│   ├── src/
│   │   └── app.js
│   └── test/
│       └── app.test.js
│
├── .gitignore
├── README.md
└── ANSWERS.md