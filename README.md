# MySQL Galera Cluster OPS
Provide a focused set of tools for executing individual operations on MySQL Galera Cluster nodes, without involving complex orchestration or business logic.

## Quick Start

### 1. Setting Up a MySQL Galera Cluster
#### 1.1 Initial Node Setup
```bash
# 1.1.1. Set bootstrap mode
export BOOTSTRAP=1

# 1.1.2. Set the cluster node addresses
export MYSQLD_WSREP_CLUSTER_ADDRESS=<node1_ip,node2_ip,node3_ip>  # Cluster node addresses
export MYSQLD_WSREP_NODE_ADDRESS=<current_node_ip> # Current node IP address

# 1.1.3. (Optional) Use a private repository (defaults to official repo if not set)
export REPO_SOURCE=1 # Enable private repository 
export REPO_SERVER_PROTOCOL=<http/https>  # Set the repo protocol (default: http)
export REPO_SERVER_NAME=<repo_server_name> # Set the repo server name (default: localhost)

# 1.1.4. Set a new password for the Galera cluster
# Recommend: Method1
export NEW_PASSWORD_FILE=<new_passoword_file_path> # Password file path (default: ./.dmypasswd.txt)
# Alternative: Method 2
export NEW_PASSWORD=<new_passoword> # Directly specify the new password

# 1.1.5. Run the setup command
make autoboot
```
#### 1.2 Setup for Other Nodes
```bash

# 1.2.1. Set the cluster node addresses
export MYSQLD_WSREP_CLUSTER_ADDRESS=<node1_ip,node2_ip,node3_ip> # Cluster node addresses
export MYSQLD_WSREP_NODE_ADDRESS=<current_node_ip> # Current node IP address

# 1.2.2. (Optional) Use a private repository (defaults to official repo if not set)
export REPO_SOURCE=1 # Enable private repository
export REPO_SERVER_PROTOCOL=<http/https> # Set the repo protocol (default: http)
export REPO_SERVER_NAME=<repo_server_name> # Set the repo server name (default: localhost)

# 1.2.3. Set a new password for the Galera cluster
# Recommend: Method1
export NEW_PASSWORD_FILE=<new_passoword_file_path> # Password file path (default: ./.dmypasswd.txt)
# Alternative: Method 2
export NEW_PASSWORD=<new_passoword> # Directly specify the new password

# 1.2.4. Run the setup command
make autorun
```

### 2. Checking the MySQL Galera Cluster
>__Note:__ `MYSQLD_WSREP_CLUSTER_SIZE` should represent the expected cluster size for validation.If the check passes, you will see output like this: "The node: <current_node_ip> of the cluster is healthy and operational." This confirms that the current node is functioning correctly within the cluster.
```bash
MYSQLD_WSREP_NODE_ADDRESS=<current_node_ip> MYSQLD_WSREP_CLUSTER_SIZE=<expected_cluster_size> make check-node
```
---
## Node Operation Details

## 1. Install MySQL Galera Cluster
### 1.1 Method1:  Install Using the Official Repository

```bash
# 1. Set the cluster node addresses
export MYSQLD_WSREP_CLUSTER_ADDRESS=<node1_ip,node2_ip,node3_ip> # Cluster node addresses
export MYSQLD_WSREP_NODE_ADDRESS=<current_node_ip>  # Current node IP address

# 2. Run the installation command
make install
```

### 1.2 Method2: Install Using a Private Repository

```bash
# 1. Set the cluster node addresses
export MYSQLD_WSREP_CLUSTER_ADDRESS=<node1_ip,node2_ip,node3_ip> # Cluster node addresses
export MYSQLD_WSREP_NODE_ADDRESS=<current_node_ip>  # Current node IP address

# 2. Configure the private repository
export REPO_SOURCE=1 # Enable private repository
export REPO_SERVER_PROTOCOL=<http/https>  # Set the repo protocol (default: http)
export REPO_SERVER_NAME=<repo_server_name> # Set the repo server name (default: localhost)

# 3. Run the installation command
make install
```

### 1.3 Method1: Install Using a Local Repository

```bash
# 1. Set the cluster node addresses
export MYSQLD_WSREP_CLUSTER_ADDRESS=<node1_ip,node2_ip,node3_ip>  # Cluster node addresses
export MYSQLD_WSREP_NODE_ADDRESS=<current node ip> # Current node IP address

# 2. Set local repo.
export REPO_SOURCE=2 # Enable local repository
export REPO_LOCAL_ROOT_PATH=<repo local root path>  # Set the local repo path (default: /opt/rpmrepo)

# 3. Run the installation command
make install
```

## 2. Start the MySQL Galera Cluster
### 2.1 Starting the Initial Node
>__Note:__ The initial node must be the one with the most recent commit, or the startup process will fail.
```bash
BOOTSTRAP=1 make start
```
### 2.2 Starting Other Nodes
```bash
make start
```

## 3. Initialize the Cluster
>__Note:__
> 1. The `init` command only needs to be executed on the initial node, as the operation will automatically sync with other nodes.
>2. Escape special characters in your new password.
>3. The initialization operation is triggered only once. However, you can run the reinit operation if necessary.

### 3.1 Recommend: Use `NEW_PASSWORD_FILE`
```bash
BOOTSTRAP=1 NEW_PASSWORD_FILE=<new passoword file path> make init-server
```

### 3.2 Alternatively: Use `NEW_PASSWORD`
```bash
BOOTSTRAP=1 NEW_PASSWORD=<new passoword> make init-server
```

## 4. Reinitialize the Cluster
>__Notice:__
>1. The `reinit` operation will completely remove all MySQL data, so proceed with caution.
>2. The `reinit` command only needs to be executed on the initial node, as the operation will automatically sync with other nodes.
>3. Escape special characters in your new password.

### 4.1 Recommended: Use `NEW_PASSWORD_FILE` 
```bash
BOOTSTRAP=1 NEW_PASSWORD_FILE=<new_password_file_path> make reinit-server
```

### 4.2 Alternatively: Use `NEW_PASSWORD`
```bash
BOOTSTRAP=1 NEW_PASSWORD=<new_passoword> make reinit-server
```


## 5. Stop the Cluster
```bash
make stop
```

## 6. Restart the Cluster
### 6.1 Restarting the Initial Node
>Note: The initial node must be the one with the most recent commit; or the startup process will fail!
```bash
BOOTSTRAP=1 make restart
```
### 6.2 Restarting Other Nodes
```bash
make restart
```

## 7. Uninstall the Cluster
>__Notice:__
>1. Stop the MySQL service before uninstalling. Alternatively, set the environment variable `STOP_SERV_ON_UNINSTALL=1` to automatically stop the service during uninstallation.
>2. By default, the uninstall-app operation does not remove MySQL data. To remove data, set `CLEAN_DATA_ON_UNINSTALL=1`.
```bash
make uninstall-app
```


