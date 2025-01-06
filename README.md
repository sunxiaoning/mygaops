# MySQL Galera Cluster OPS
Provide a focused set of tools for executing individual operations on MySQL Galera Cluster nodes, without involving complex orchestration or business logic.

## Quick Start

### 1 Download and Set Up the MyGAOPS Project
>__Note:__ The setup commands must be executed sequentially on all nodes to ensure successful deployment.
#### 1.1 Method 1: Using the Release Package

```bash

# 1. Download the application package
curl -fsSLo <dest_path/mygaops.tar.gz> https://github.com/sunxiaoning/mygaops/releases/tag/v<pkg_version>

# 2. Unzip the app pkg
tar -zxvf <dest_path/mygaops.tar.gz> -C <project_path>
```

#### 1.2 Method2: Using the source code

```bash

# 1. Clone the project 
git clone --recursive git@github.com:sunxiaoning/mygaops <project_path>
# or 
git clone --recursive git@gitee.com:williamsun/mygaops.git <project_path>

# 2. change to <project_path> and checkout the target app pkg_version
cd <project_path>
git checkout v<pkg_version>
```

### 2 Setting Up a MySQL Galera Cluster
>__Note:__
>1. To successfully set up a MySQL Galera Cluster, you must have sudo or root privileges.
>2. The recommended test environments are Rocky Linux 8 and RHEL 8; other operating systems are currently unsupported to ensure optimal setup and reliability.
>3. Galera-4 and MySQL-WSREP 8.0 are required; Galera-3 and MySQL-WSREP 5.7 are not recommended and have not been tested.
>4. If you specify a custom version of Galera-4 and MySQL WSREP 8.0, you must ensure that the same version is installed on all cluster nodes.

#### 2.1 Start Up the MySQL Galera Cluster
>__Note:__
> 1. Prepare the MySQL Galera Cluster nodes, the recommend count is 3 or 5, min count is 2.
> 2. The setup command must be executed on all nodes in sequence successfuly.
> 3. The first node must be started in bootstrap mode, while all subsequent nodes should be started in join mode.

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
export REPO_SERVER_PORT=<repo_server_port> # Set the repo server port (default: 80)

# 4. (Optional) Specify the version of the software package to be installed.
export GALERA_VERSION=<GALERA_VERSION> # Set the Galera Version (default: 26.4.20)
export MYSQL_WSREP_VERSION=<MYSQL_WSREP_VERSION> # Set the MySQL WSREP Version (default: 8.0.39)

# 5. Run the setup command
sudo bash -c "<project_path>/mygaops.sh autorun"
```

#### 2.2. Initialize the MySQL Galera Cluster
>__Note:__
>1. The `init-server` command is run only on the initial node to initialize the cluster.
>2. If the user don't specfiy the root password, mygaops will generate a safe random password. 
>3. If you wish to set a new root password, escape special characters in the password string.

```bash

# 1. (Optional) Set a new password for the MySQL Galera cluster
#    Recommended: Use a password file (Method 1)
export NEW_PASSWORD_FILE="/path/to/password_file"  # Path to password file (default: ~/.mygaops/.dmypasswd.txt)

#    Alternatively, directly specify the new password (Method 2)
export NEW_PASSWORD="NewSecurePassword123!"  # Manually set new password

# 2. Run the init-server command
sudo bash -c "<project_path>/mygaops.sh init-server"
```

### 3 Checking the MySQL Galera Cluster
>__Note:__ 
> 1. `MYSQLD_WSREP_CLUSTER_SIZE` should represent the expected cluster size for validation.If the check passes, you will see output like this: "The node: <current_node_ip> of the cluster is healthy and operational." This confirms that the current node is functioning correctly within the cluster.
> 2. The `check-cluster` command must be executed on all nodes in sequence successfuly.

```bash
sudo MYSQLD_WSREP_NODE_ADDRESS=<current_node_ip> MYSQLD_WSREP_CLUSTER_SIZE=<expected_cluster_size> bash -c "<project_path>/mygaops.sh check-cluster"
```
---
## Node Operation Details

### 1 Install MySQL Galera Cluster
#### 1.1 Method1:  Install Using the Official Repository

```bash
# 1. Set the cluster node addresses
export MYSQLD_WSREP_CLUSTER_ADDRESS=<node1_ip,node2_ip,node3_ip> # Cluster node addresses
export MYSQLD_WSREP_NODE_ADDRESS=<current_node_ip>  # Current node IP address

# 2. Run the installation command
sudo bash -c "<project_path>/mygaops.sh install"
```

#### 1.2 Method2: Install Using a Private Repository

```bash
# 1. Set the cluster node addresses
export MYSQLD_WSREP_CLUSTER_ADDRESS=<node1_ip,node2_ip,node3_ip> # Cluster node addresses
export MYSQLD_WSREP_NODE_ADDRESS=<current_node_ip>  # Current node IP address

# 2. Configure the private repository
export REPO_SOURCE=1 # Enable private repository
export REPO_SERVER_PROTOCOL=<http/https>  # Set the repo protocol (default: http)
export REPO_SERVER_NAME=<repo_server_name> # Set the repo server name (default: localhost)
export REPO_SERVER_PORT=<repo_server_port> # Set the repo server port (default: 80)


# 3. Run the installation command
sudo bash -c "<project_path>/mygaops.sh install"
```

#### 1.3 Method3: Install Using a Local Repository

```bash
# 1. Set the cluster node addresses
export MYSQLD_WSREP_CLUSTER_ADDRESS=<node1_ip,node2_ip,node3_ip>  # Cluster node addresses
export MYSQLD_WSREP_NODE_ADDRESS=<current node ip> # Current node IP address

# 2. Set local repo.
export REPO_SOURCE=2 # Enable local repository
export REPO_LOCAL_ROOT_PATH=<repo local root path>  # Set the local repo path (default: /opt/rpmrepo)

# 3. Run the installation command
sudo bash -c "<project_path>/mygaops.sh install"
```

### 2 Start the MySQL Galera Cluster
#### 2.1 Starting the Initial Node
>__Note:__ The initial node must be the one with the most recent commit, or the startup process will fail.
```bash
# 1. Set bootstrap mode
export BOOTSTRAP=1

# 2. Run the start command
sudo bash -c "<project_path>/mygaops.sh start"
```
#### 2.2 Starting Other Nodes
```bash
# 1. Run the start command
sudo bash -c "<project_path>/mygaops.sh start"
```

### 3 Initialize the Cluster
>__Note:__
> 1. The `init` command only needs to be executed on the initial node, as the operation will automatically sync with other nodes.
>2. Escape special characters in your new password.
>3. If new password is not specified, mygaops will generate an safe and random password.
>4. The initialization operation is triggered only once. However, you can run the reinit operation if necessary.

#### 3.1 Generate `NEW_PASSWORD`
```bash

# 1. Set bootstrap mode
export BOOTSTRAP=1

# 2. Run the init-server command
sudo bash -c "<project_path>/mygaops.sh init-server
```

#### 3.2 Specify `NEW_PASSWORD` by Using `NEW_PASSWORD_FILE` (Recommend)
```bash
# 1. Set bootstrap mode
export BOOTSTRAP=1

# 2. Set the new password file path
export NEW_PASSWORD_FILE=<new_passoword_file_path>

# 3. Run the init-server command
sudo bash -c "<project_path>/mygaops.sh init-server"
```

#### 3.3 Specify `NEW_PASSWORD` by Using `NEW_PASSWORD`
```bash

# 1. Set bootstrap mode
export BOOTSTRAP=1

# 2. Run the init-server command
sudo NEW_PASSWORD=<new passoword> bash -c "<project_path>/mygaops.sh init-server"
```

### 4 Checking the Galera node
>__Note:__ 
> 1. If the check passes, you will see output like this: "The node: <current_node_ip> of the cluster is healthy and operational." This confirms that the current node is functioning correctly within the cluster.

```bash
sudo MYSQLD_WSREP_NODE_ADDRESS=<current_node_ip> bash -c "<project_path>/mygaops.sh check-cluster"
```

### 5 Checking the Galera Cluster
>__Note:__ 
> 1. `MYSQLD_WSREP_CLUSTER_SIZE` should represent the expected cluster size for validation.If the check passes, you will see output like this: "The node: <current_node_ip> of the cluster is healthy and operational." This confirms that the current node is functioning correctly within the cluster.

```bash
sudo MYSQLD_WSREP_NODE_ADDRESS=<current_node_ip> MYSQLD_WSREP_CLUSTER_SIZE=<expected_cluster_size> bash -c "<project_path>/mygaops.sh check-cluster"
```

### 6 Reinitialize the Cluster
>__Note:__
>1. The `reinit` operation will completely remove all MySQL data, so proceed with caution.
>2. The `reinit` command only needs to be executed on the initial node, as the operation will automatically sync with other nodes.
>3. Escape special characters in your new password.

#### 6.1 Specify `NEW_PASSWORD` by Using `NEW_PASSWORD_FILE` (Recommend)
```bash
# 1. Set bootstrap mode
export BOOTSTRAP=1

# 2. Set the new password file path
export NEW_PASSWORD_FILE=<new_password_file_path>

# 3. Run the reinit-server command
sudo bash -c "<project_path>/mygaops.sh reinit-server"
```

#### 6.2 Specify `NEW_PASSWORD` by Using `NEW_PASSWORD`
```bash
# 1. Set bootstrap mode
export BOOTSTRAP=1

# 2. Run the reinit-server command
sudo NEW_PASSWORD=<new_passoword> bash -c "<project_path>/mygaops.sh reinit-server"
```

### 7 Stop the Cluster
```bash

# 1. Run the stop command
sudo bash -c "<project_path>/mygaops.sh stop"
```

### 8 Restart the Cluster
#### 8.1 Restarting the Initial Node
>Note: The initial node must be the one with the most recent commit; or the startup process will fail!
```bash

# 1. Set bootstrap mode
export BOOTSTRAP=1

# 2. Run the restart command
sudo bash -c "<project_path>/mygaops.sh restart"
```
#### 8.2 Restarting Other Nodes
```bash

# 1. Run the restart command
sudo bash -c "<project_path>/mygaops.sh restart"
```

### 9 Uninstall the Cluster
>__Note:__
>1. Stop the MySQL service before uninstalling. Alternatively, set the environment variable `STOP_SERV_ON_UNINSTALL=1` to automatically stop the service during uninstallation.
>2. By default, the uninstall-app operation does not remove MySQL data. To remove data, set `CLEAN_DATA_ON_UNINSTALL=1`.
```bash
1. (Optional) Set the uninstall options
export STOP_SERV_ON_UNINSTALL=1
export CLEAN_DATA_ON_UNINSTALL=1

2. Run the uninstall-app command
sudo bash -c "<project_path>/mygaops.sh uninstall-app"
```


