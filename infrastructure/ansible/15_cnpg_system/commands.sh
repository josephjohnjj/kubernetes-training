

kubectl create -f cnpg-pool.yaml 
kubectl create -f cnpg-sc.yaml 

kubectl patch storageclass cnpg-sc   -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'


helm repo add cnpg https://cloudnative-pg.github.io/charts

helm upgrade --install cnpg --namespace cnpg-system --create-namespace cnpg/cloudnative-pg

helm upgrade --install cnpg --namespace cnpg-database --create-namespace --values values.yaml cnpg/cluster

# Create database
# -----------------

postgres=# CREATE USER keycloak WITH PASSWORD 'keycloak-pwd';
CREATE ROLE
postgres=# CREATE DATABASE keycloak OWNER keycloak;
CREATE DATABASE
postgres=# GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
GRANT
postgres=# \c keycloak
You are now connected to database "keycloak" as user "postgres".
keycloak=# ALTER SCHEMA public OWNER TO keycloak;
ALTER SCHEMA
keycloak=# GRANT ALL ON SCHEMA public TO keycloak;
GRANT
keycloak=# ALTER DEFAULT PRIVILEGES IN SCHEMA public
keycloak-# GRANT ALL ON TABLES TO keycloak;
ALTER DEFAULT PRIVILEGES
keycloak=# ALTER DEFAULT PRIVILEGES IN SCHEMA public
keycloak-# GRANT ALL ON SEQUENCES TO keycloak;
ALTER DEFAULT PRIVILEGES
keycloak=# \dn+
                          List of schemas
  Name  |  Owner   |  Access privileges   |      Description       
--------+----------+----------------------+------------------------
 public | keycloak | keycloak=UC/keycloak+| standard public schema
        |          | =U/keycloak          | 
(1 row)



kubectl get secret cnpg-cluster-superuser -n cnpg-database -o jsonpath="{.data.username}" | base64 --decode

kubectl get secret cnpg-cluster-superuser -n cnpg-database -o jsonpath="{.data.password}" | base64 --decode
    

