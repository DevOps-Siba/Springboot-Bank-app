# Dockerized Spring Boot + MySQL – Problem & Solution Summary

## Overview

This document explains **what exactly went wrong** while containerizing the Spring Boot Bank application and **how each issue was resolved**, step by step. It serves as a reference for debugging, learning, and interview preparation.

---

## Final Working State

* Spring Boot app running in Docker container (`bankapp:latest`)
* MySQL running in a separate Docker container
* Both containers connected via a custom Docker bridge network (`bankapp`)
* Application accessible on port **8080**

---

## Problems Faced & Solutions

### 1. Image Not Found (`pull access denied`)

**Problem:**
Docker could not find `bankapp:latest` while running the container.

**Reason:**
The image was never built. `docker run` does not build images.

**Solution:**

```bash
docker build -t bankapp .
```

---

### 2. Maven Could Not Find `pom.xml`

**Problem:**

```
There is no POM in this directory (/app)
```

**Reason:**
Source code was copied to the wrong directory inside the container.

**Solution:**

```dockerfile
WORKDIR /app
COPY . .
```

Ensured `pom.xml` existed in `/app`.

---

### 3. Wrong Maven Flag

**Problem:**
Incorrect flag used: `-DskipTest=true`

**Solution:**

```dockerfile
RUN mvn clean package -DskipTests
```

---

### 4. Invalid Runtime Base Image

**Problem:**

```
manifest for openjdk:17-alpine not found
```

**Reason:**
The image tag `openjdk:17-alpine` does not exist.

**Solution:**
Replaced with a valid official runtime image:

```dockerfile
FROM eclipse-temurin:17-jre-alpine
```

---

### 5. Database Connection Failed Using `localhost`

**Problem:**
Spring Boot could not connect to MySQL.

**Reason:**
Inside Docker, `localhost` refers to the same container, not another container.

**Solution:**

* Created a custom Docker network
* Used MySQL container name as hostname

```bash
docker network create bankapp
```

```properties
jdbc:mysql://mysql:3306/BankDB
```

---

### 6. Shell Command Broke Due to `&`

**Problem:**
The `docker run` command failed unexpectedly.

**Reason:**
The `&` character in JDBC URL was interpreted by the shell.

**Solution:**
Wrapped the URL in quotes:

```bash
-e "SPRING_DATASOURCE_URL=jdbc:mysql://mysql:3306/BankDB?useSSL=false&serverTimezone=UTC"
```

---

### 7. Dangling `<none>` Images

**Problem:**
Docker showed images with `<none>` tags.

**Reason:**
Images were built without a tag name.

**Solution:**
Built image with explicit tag:

```bash
docker build -t bankapp .
```

---

## Final Dockerfile (Working)

```dockerfile
# Stage 1: Build
FROM maven:3.8.3-openjdk-17 AS builder
WORKDIR /app
COPY . .
RUN mvn clean package -DskipTests

# Stage 2: Runtime
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

---

## Final Run Commands

### MySQL Container

```bash
docker run -d \
--name mysql \
--network bankapp \
-e MYSQL_DATABASE=BankDB \
-e MYSQL_ROOT_PASSWORD=Test@123 \
mysql:8.0
```

### Spring Boot Container

```bash
docker run -d \
--name BankApp \
--network bankapp \
-p 8080:8080 \
-e "SPRING_DATASOURCE_URL=jdbc:mysql://mysql:3306/BankDB?useSSL=false&serverTimezone=UTC" \
-e SPRING_DATASOURCE_USERNAME=root \
-e SPRING_DATASOURCE_PASSWORD=Test@123 \
bankapp:latest
```

---

## Key Learnings (Interview Ready)

* `docker run` does not build images
* Image tagging is mandatory
* Multi-stage builds reduce image size
* Containers communicate using service/container names
* Always use valid, official base images
* Quote environment variables containing special characters

---

## Final Result

✅ Application running successfully on Docker
✅ MySQL connected properly
✅ Production-style setup achieved
# Solution.md

## Problem Overview

The Spring Boot BankApp container was getting **created successfully but exiting immediately** after startup.

Docker containers status showed:

* `mysql` container: **Up and running**
* `BankApp` container: **Exited (1)**

On checking logs using:

```bash
docker logs BankApp
```

The application failed during **database initialization**.

---

## Exact Error

The key error message was:

```
Public Key Retrieval is not allowed
```

This error occurred while Spring Boot + Hibernate tried to connect to the MySQL database.

---

## Root Cause (Why this happened)

1. The application was using **MySQL 8** (official Docker image).
2. MySQL 8 uses the authentication plugin:

   ```
   caching_sha2_password
   ```
3. The MySQL JDBC driver **blocks public key retrieval by default** for security reasons.
4. Because of this restriction, Hibernate could not authenticate with MySQL.
5. As a result:

   * JPA EntityManagerFactory failed
   * Spring Boot startup failed
   * Container exited

This was **not a Docker issue**, **not a network issue**, and **not a credentials issue**.

---

## How We Diagnosed

* Verified MySQL container was running
* Verified Docker network was correct (`bankapp`)
* Verified application logs showed DB authentication failure
* Identified MySQL authentication error from stack trace

---

## Final Solution (Correct Fix)

We updated the JDBC URL to explicitly allow public key retrieval.

### Updated Docker Run Command

```bash
docker run -d \
--name BankApp \
--network bankapp \
-p 8080:8080 \
-e "SPRING_DATASOURCE_URL=jdbc:mysql://mysql:3306/BankDB?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC" \
-e SPRING_DATASOURCE_USERNAME=root \
-e SPRING_DATASOURCE_PASSWORD=Test@123 \
bankapp:latest
```

### Key Fix Parameter

```
allowPublicKeyRetrieval=true
```

This allows the MySQL JDBC driver to securely retrieve the server public key during authentication.

---

## Result After Fix

* Hibernate successfully connected to MySQL
* JPA EntityManagerFactory initialized
* Spring Boot application started successfully
* Container status:

```bash
docker ps
```

```
BankApp   Up
mysql    Up
```

---

## Interview-Ready One Line Explanation

> The container failed because MySQL 8 blocks public key retrieval by default. Adding `allowPublicKeyRetrieval=true` in the JDBC URL allowed secure authentication and fixed the startup issue.

---

## Final Status

✅ Docker image built correctly
✅ Containers running
✅ Application accessible on port 8080

---

**Issue resolved successfully**

---

**Status:** RESOLVED 🎉




#------------------------------------------------------------
# Solution.md

## Problem Overview

The Spring Boot BankApp container was getting **created successfully but exiting immediately** after startup.

Docker containers status showed:

* `mysql` container: **Up and running**
* `BankApp` container: **Exited (1)**

On checking logs using:

```bash
docker logs BankApp
```

The application failed during **database initialization**.

---

## Exact Error

The key error message was:

```
Public Key Retrieval is not allowed
```

This error occurred while Spring Boot + Hibernate tried to connect to the MySQL database.

---

## Root Cause (Why this happened)

1. The application was using **MySQL 8** (official Docker image).
2. MySQL 8 uses the authentication plugin:

   ```
   caching_sha2_password
   ```
3. The MySQL JDBC driver **blocks public key retrieval by default** for security reasons.
4. Because of this restriction, Hibernate could not authenticate with MySQL.
5. As a result:

   * JPA EntityManagerFactory failed
   * Spring Boot startup failed
   * Container exited

This was **not a Docker issue**, **not a network issue**, and **not a credentials issue**.

---

## How We Diagnosed

* Verified MySQL container was running
* Verified Docker network was correct (`bankapp`)
* Verified application logs showed DB authentication failure
* Identified MySQL authentication error from stack trace

---

## Final Solution (Correct Fix)

We updated the JDBC URL to explicitly allow public key retrieval.

### Updated Docker Run Command

```bash
docker run -d \
--name BankApp \
--network bankapp \
-p 8080:8080 \
-e "SPRING_DATASOURCE_URL=jdbc:mysql://mysql:3306/BankDB?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC" \
-e SPRING_DATASOURCE_USERNAME=root \
-e SPRING_DATASOURCE_PASSWORD=Test@123 \
bankapp:latest
```

### Key Fix Parameter

```
allowPublicKeyRetrieval=true
```

This allows the MySQL JDBC driver to securely retrieve the server public key during authentication.

---

## Result After Fix

* Hibernate successfully connected to MySQL
* JPA EntityManagerFactory initialized
* Spring Boot application started successfully
* Container status:

```bash
docker ps
```

```
BankApp   Up
mysql    Up
```

---

## Interview-Ready One Line Explanation

> The container failed because MySQL 8 blocks public key retrieval by default. Adding `allowPublicKeyRetrieval=true` in the JDBC URL allowed secure authentication and fixed the startup issue.

---

## Final Status

✅ Docker image built correctly
✅ Containers running
✅ Application accessible on port 8080

---

**Issue resolved successfully**


