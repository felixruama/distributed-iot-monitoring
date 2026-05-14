## Réplicas MongoDB

### Passo 1: Atualizar o ficheiro `hosts` (Obrigatório)

Para que o Python e o MongoDB Compass consigam encontrar as bases de dados dentro do Docker, temos de ensinar o nosso computador a reconhecer os nomes delas.

* **No Windows:**
1. Abre o Bloco de Notas como **Administrador**.
2. Abre o ficheiro: `C:\Windows\System32\drivers\etc\hosts`.
3. Adiciona esta linha no fim do ficheiro e guarda:
`127.0.0.1 mongodb1 mongodb2 mongodb3`


* **No Mac:**
1. Abre o Terminal.
2. Escreve `sudo nano /etc/hosts` e introduz a tua password.
3. Usa as setas para ir até ao fim do ficheiro e adiciona:
`127.0.0.1 mongodb1 mongodb2 mongodb3`
4. Clica `Ctrl + O` e `Enter` para guardar, e `Ctrl + X` para sair.



### Passo 2: Atualizar o `docker-compose.yml`

Substitui o bloco antigo do MongoDB no `docker-compose.yml` por estes três blocos. Repara que **as portas foram alteradas e o comando `--port` foi adicionado**:

```yaml
  mongodb1:
    image: mongo:latest
    container_name: mongodb1
    command: ["--port", "27018", "--replSet", "rs0", "--bind_ip_all"]
    ports:
      - "27018:27018"
    volumes:
      - mongo1_data:/data/db

  mongodb2:
    image: mongo:latest
    container_name: mongodb2
    command: ["--port", "27019", "--replSet", "rs0", "--bind_ip_all"]
    ports:
      - "27019:27019"
    volumes:
      - mongo2_data:/data/db

  mongodb3:
    image: mongo:latest
    container_name: mongodb3
    command: ["--port", "27020", "--replSet", "rs0", "--bind_ip_all"]
    ports:
      - "27020:27020"
    volumes:
      - mongo3_data:/data/db

volumes:
  mongo1_data:
  mongo2_data:
  mongo3_data:

```

### Passo 3: Limpar os dados antigos e iniciar

Abre o terminal na pasta do projeto e corre:

1. `docker-compose down -v` *(Atenção: isto apaga os dados antigos da BD)*
2. `docker-compose up -d`

### Passo 4: Formar a "Família" (O Replica Set)

Temos de dizer ao MongoDB que estes 3 contentores agora trabalham juntos e escutam pelas portas corretas.

1. No terminal, entra na BD principal:
`docker exec -it mongodb1 mongosh --port 27018`
2. Copia, cola e executa os seguintes comandos (um de cada vez):
```javascript
rs.initiate()

```


*(Espera 2 ou 3 segundos e carrega no Enter até aparecer "primary" no lado esquerdo)*
```javascript
cfg = rs.conf()

```


```javascript
cfg.members[0].host = "mongodb1:27018"

```


```javascript
rs.reconfig(cfg, {force: true})

```


```javascript
rs.add("mongodb2:27019")

```


```javascript
rs.add("mongodb3:27020")

```


3. Escreve `exit` para sair.

### Passo 5: Atualizar os Scripts Python

A partir de agora, o nosso código é 100% resistente a falhas! Em **todos** os ficheiros Python onde tínhamos o URI da base de dados, muda para o URI completo (repara que retirámos o `directConnection`):

`mongodb://mongodb1:27018,mongodb2:27019,mongodb3:27020/?replicaSet=rs0`
