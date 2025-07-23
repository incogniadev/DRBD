# Deploying a Simple WebApp on Docker with NFS

This guide covers the steps to deploy a simple WebApp using Docker, with its data stored on an NFS volume.

## Prerequisites

- Docker installed on your Debian system.
- NFS server configured and running on your DRBD setup.
- Ensure NFS is mounted on `/mnt/nfs-docker` or your NFS mount point on Node 3.

## Steps

1. **Create a Dockerfile for your WebApp:**

   ```dockerfile
   FROM ubuntu:20.04
   RUN apt-get update && apt-get install -y nginx
   COPY . /var/www/html
   CMD ["nginx", "-g", "daemon off;"]
   ```

2. **Build the Docker Image:**

   Navigate to your project directory containing the Dockerfile.

   ```bash
   docker build -t my-webapp .
   ```

3. **Run the Docker Container:**

   Use the following command to start your container and map the NFS volume.

   ```bash
   docker run -d -p 80:80 -v /mnt/nfs-docker/my-webapp:/var/www/html my-webapp
   ```

4. **Verify the Deployment:**

   Open a web browser and navigate to `http://your-node-ip`. You should see the deployed WebApp.

That's it! You've deployed a simple WebApp using Docker with NFS storage.
