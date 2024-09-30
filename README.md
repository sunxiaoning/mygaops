# MySQL Galera Cluster OPS
Provide a focused set of tools for executing individual operations on MySQL Galera Cluster nodes, without involving complex orchestration or business logic.

## Quick Start

### 1. Setting Up a MySQL Galera Cluster
>__Note:__
>1. To successfully set up a MySQL Galera Cluster, you must have sudo or root privileges.
>2. The recommended test environments are Rocky Linux 8 and RHEL 8; other operating systems are currently unsupported to ensure optimal setup and reliability.
>3. Galera-4 and MySQL-WSREP 8.0 are required; Galera-3 and MySQL-WSREP 5.7 are not recommended and have not been tested.
>4. If you specify a custom version of Galera-4 and MySQL WSREP 8.0, you must ensure that the same version is installed on all cluster nodes.

#### 1.1 Start Up the MySQL Galera Cluster
>__Note:__
> The first node must be started in bootstrap mode, while all subsequent nodes should be started in join mode.

```bash
# 1. Set the startup mode (defaults to join mode, 0)
#    Bootstrap mode: Used only for the initial node in the cluster to initialize it.
#    Join mode: Used for all subsequent nodes to join the initialized cluster.
export BOOTSTRAP=1  # 1: bootstrap mode for the first node, 0: join mode for other nodes

# 2. Set the cluster node addresses
export MYSQLD_WSREP_CLUSTER_ADDRESS=<node1_ip,node2_ip,node3_ip>  # Cluster node addresses
export MYSQLD_WSREP_NODE_ADDRESS=<current_node_ip> # Current node IP address


# 3. (Optional) Use a private repository for package installation
#    Default: 0 (use the official repository)
export REPO_SOURCE=1 # 0: official repo, 1. private repo 2. local repo
export REPO_SERVER_PROTOCOL=<http/https>  # Set the repo protocol (default: http)
export REPO_SERVER_NAME=<repo_server_name> # Set the repo server name (default: localhost)

# 4. (Optional) Specify the version of the software package to be installed.
export GALERA_VERSION=<GALERA_VERSION> # Set the Galera Version (default: 26.4.19)
export MYSQL_WSREP_VERSION=<MYSQL_WSREP_VERSION> # Set the MySQL WSREP Version (default: 8.0.37)

# 5. Run the setup command
sudo make autorun
```

#### 1.2. Initialize the MySQL Galera Cluster
>__Note:__
>1. The `init-server` command is run only on the initial node to initialize the cluster.
>2. If you wish to set a new root password, escape special characters in the password string.

```bash

# 1. (Optional) Set a new password for the MySQL Galera cluster
#    Recommended: Use a password file (Method 1)
export NEW_PASSWORD_FILE="/path/to/password_file"  # Path to password file (default: ~/.mygaops/.dmypasswd.txt)

#    Alternatively, directly specify the new password (Method 2)
export NEW_PASSWORD="NewSecurePassword123!"  # Manually set new password

# 2. Run the init-server command
sudo make init-server
```

### 2. Checking the MySQL Galera Cluster
>__Note:__ `MYSQLD_WSREP_CLUSTER_SIZE` should represent the expected cluster size for validation.If the check passes, you will see output like this: "The node: <current_node_ip> of the cluster is healthy and operational." This confirms that the current node is functioning correctly within the cluster.
```bash
sudo MYSQLD_WSREP_NODE_ADDRESS=<current_node_ip> MYSQLD_WSREP_CLUSTER_SIZE=<expected_cluster_size> make check-cluster
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
sudo make install
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
sudo make install
```

### 1.3 Method3: Install Using a Local Repository

```bash
# 1. Set the cluster node addresses
export MYSQLD_WSREP_CLUSTER_ADDRESS=<node1_ip,node2_ip,node3_ip>  # Cluster node addresses
export MYSQLD_WSREP_NODE_ADDRESS=<current node ip> # Current node IP address

# 2. Set local repo.
export REPO_SOURCE=2 # Enable local repository
export REPO_LOCAL_ROOT_PATH=<repo local root path>  # Set the local repo path (default: /opt/rpmrepo)

# 3. Run the installation command
sudo make install
```

## 2. Start the MySQL Galera Cluster
### 2.1 Starting the Initial Node
>__Note:__ The initial node must be the one with the most recent commit, or the startup process will fail.
```bash
# 1. Set bootstrap mode
export BOOTSTRAP=1

# 2. Run the start command
sudo make start
```
### 2.2 Starting Other Nodes
```bash
# 1. Run the start command
sudo make start
```

## 3. Initialize the Cluster
>__Note:__
> 1. The `init` command only needs to be executed on the initial node, as the operation will automatically sync with other nodes.
>2. Escape special characters in your new password.
>3. The initialization operation is triggered only once. However, you can run the reinit operation if necessary.

### 3.1 Recommend: Use `NEW_PASSWORD_FILE`
```bash
# 1. Set bootstrap mode
export BOOTSTRAP=1

# 2. Set the new password file path
export NEW_PASSWORD_FILE=<new_passoword_file_path>

# 3. Run the init-server command
sudo make init-server
```

### 3.2 Alternatively: Use `NEW_PASSWORD`
```bash

# 1. Set bootstrap mode
export BOOTSTRAP=1

# 2. Run the init-server command
NEW_PASSWORD=<new passoword> make init-server
```

## 4. Reinitialize the Cluster
>__Note:__
>1. The `reinit` operation will completely remove all MySQL data, so proceed with caution.
>2. The `reinit` command only needs to be executed on the initial node, as the operation will automatically sync with other nodes.
>3. Escape special characters in your new password.

### 4.1 Recommended: Use `NEW_PASSWORD_FILE` 
```bash
# 1. Set bootstrap mode
export BOOTSTRAP=1

# 2. Set the new password file path
export NEW_PASSWORD_FILE=<new_password_file_path>

# 3. Run the reinit-server command
sudo make reinit-server
```

### 4.2 Alternatively: Use `NEW_PASSWORD`
```bash
# 1. Set bootstrap mode
export BOOTSTRAP=1

# 2. Run the reinit-server command
NEW_PASSWORD=<new_passoword> make reinit-server
```


## 5. Stop the Cluster
```bash

# 1. Run the stop command
sudo make stop
```

## 6. Restart the Cluster
### 6.1 Restarting the Initial Node
>Note: The initial node must be the one with the most recent commit; or the startup process will fail!
```bash

# 1. Set bootstrap mode
export BOOTSTRAP=1

# 2. Run the restart command
sudo make restart
```
### 6.2 Restarting Other Nodes
```bash

# 1. Run the restart command
sudo make restart
```

## 7. Uninstall the Cluster
>__Note:__
>1. Stop the MySQL service before uninstalling. Alternatively, set the environment variable `STOP_SERV_ON_UNINSTALL=1` to automatically stop the service during uninstallation.
>2. By default, the uninstall-app operation does not remove MySQL data. To remove data, set `CLEAN_DATA_ON_UNINSTALL=1`.
```bash
1. (Optional) Set the uninstall options
export STOP_SERV_ON_UNINSTALL=1
export CLEAN_DATA_ON_UNINSTALL=1

2. Run the uninstall-app command
sudo make uninstall-app
```


