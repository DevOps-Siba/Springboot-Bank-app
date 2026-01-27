#-------------stage1------------------
  
# Pull base image so that we can use to build the jar file 
FROM maven:3.8.3-openjdk-17 AS a builder

# Create a workdir where code and jar file will be stored  
WORKDIR /app 

# Copy our code from host to container  
COPY . /app

# Build the app to generate jar file  
RUN mvn clean install -DskipTest=true

# Expose the port so that the port can be mapped with the host  
EXPOSE 8080  

# Execute the jar file using java command  
ENTRYPOINT ["java", "jar", "/bankapp.jar"]  

