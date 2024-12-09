# HATS: Hadoop Ansible Test Suite 

HATS is a versatile, menu-driven suite of shell scripts designed to streamline testing on Hadoop YARN clusters. By leveraging Ansible playbooks, it provides a seamless way to execute and manage a variety of tests, ensuring flexibility and ease of use for both interactive and automated workflows.  

**Key Features:** 
- **Menu-Driven Interface**: Select specific tests to run interactively via a user-friendly menu.  
- **Non-Interactive Mode**: Automate testing with command-line arguments for CI/CD pipelines or scheduled tasks.  
- **Comprehensive Test Coverage**: Includes smoke tests for critical components like HDFS, MapReduce, and Spark, ensuring cluster health and functionality.
- **Configuration File Validation:** Leverages the Python lxml library to test and validate configuration files for correctness and compliance.
- **Extensible Framework**: Add new Ansible playbooks or roles to expand the suite’s testing capabilities.  
- **Performance Testing (Planned)**: Future support for benchmarking and evaluating cluster performance.  

HATS simplifies the management of cluster testing while maintaining flexibility, making it an indispensable tool for developers and administrators working with Hadoop ecosystems.

## Smoke tests

The script `hats-smoke.sh` launches a series of tests (HDFS, MapReduce, Spark, configuration files inspections) on a YARN-managed Hadoop cluster with Ansible. 

The script allows you to interactively configure your Ansible connection data, so that you can use the same script for testing multiple Hadoop clusters. 

Run with: 

```
./hats-smoke.sh <my_cloud> <my_project>
```

The parameters `<my_cloud>` and `<my_project>` tell the script where to find your ansible inventory file, they can be changed by you depending on where you want to save the inventory file.

Run the script without arguments to get an usage message:

```
./hats-smoke.sh
```
### Smoke-test your own Hadoop cluster

To test your own Hadoop cluster "XYZ", follow these steps:

1. Launch the script with
	```
	./hats-smoke.sh MYCLOUD XYZ
	```
		
	If the Ansible inventory file
	```
	MYCLOUD/ansible/XYZ/ansible_inventory_hats.ini
	``` 
	does not already exist, it will be created.

2. You will be prompted to enter your Ansible username and the Ansible host

	```
	The Ansible username is the user who runs the test jobs on the cluster
	Enter your ansible username (enter to keep default)  [myuser]: 
	The Ansible host is the host where to access the Hadoop cluster
	Enter your ansible hostname (enter to keep default)  [myhost]: 
	```

#### Non-interactive usage

For non-interactive runs, use the option `-n`:

```
./hats-smoke.sh -n MYCLOUD XYZ
```
making sure that your Ansible inventory `MYCLOUD/ansible/XYZ/ansible_inventory_hats.ini` is configured appropriately.



## How to configure the Ansible inventory

The Ansible inventory should contain the hostname/address of the node used to access the cluster. Here's how the inventory file for a cluster running on `localhost` looks like:

```
[clientnode]
hadoopclientnode ansible_host=localhost

[clientnode:vars]
ansible_user=myusername
```

In general, if the node where you access the cluster has the IP address `xx.yy.zz.ww` and you want to run the tests as `hdfs` then the inventory file looks like:

```
[clientnode]
hadoopclientnode ansible_host="xx.yy.zz.ww"

[clientnode:vars]
ansible_user=hdfs
```

Check if the Ansible connection works with:
```
ssh hdfs@xx.yy.zz.ww
```

**Note:** I would not recommended to use `hdfs` in general for running tests, but you can use it if you do not have any other users on your node. Let us rewrite a generic inventory file for `testuser` in place of `hdfs`:

```
[clientnode]
hadoopclientnode ansible_host="xx.yy.zz.ww"

[clientnode:vars]
ansible_user=testuser
```


## How to set up a passwordless SSH connection

If you have a private/public key, it is convenient to use an ssh agent. You can start it with
the command
```
ssh-agent
```

By running 
```
ssh-add <my private id filename>
```
(or simply `ssh-add` if you want to add the _default_ private key `~/.ssh/id_rsa`) you will be required to input the password for your private key. 

The agent from now on takes care of providing 
authentication on all hosts where you saved the corresponding public key (by default `~/.ssh/id_rsa.pub`, that
needs to be saved in the file `~/.ssh/authorized_keys` as a single line and watching out for the right permissions).

If you set up such a passwordless ssh connection, Ansible will not ask you to enter any password interactively, so using a ssh agent is **strongly recommended**.

### Step-by-step if you do not have a key

1. create a private/public key (e.g. `~/.ssh/id_rsa` with public key `~/.ssh/id_rsa.pub` ) by using the command `ssh-keygen` (just type it, don't worry, you'll be prompted for the file where you want to save your key, etc.)
2. copy the public key to the account that you want to use for testing (e.g. `testuser`):
   ```
   ssh-copy-id -i ~/.ssh/id_rsa.pub testuser@xx.yy.zz.ww
   ```
3. test the connection with
   ```
   ssh testuser@xx.yy.zz.ww
   ```
   (you should be prompted for your key's password)
4. start `ssh-agent` with

 	 ```
 	  eval `ssh-agent -s`
  	 ```
5. add your new private key (e.g.`~/.ssh/id_rsa`) to the agent so you don't need to type your password all the time
   ```
   ssh-add ~/.ssh/id_rsa
   ```
6. run a small PING test 

   ```
   CLOUD=MYCLOUD;PROJ=XYZ;ansible-playbook -T 10 -i $CLOUD/ansible/$PROJ/ansible_inventory_hats.ini common/ansible/playbooks/ping_hosts.yml
   ```
7. run the full smoke tests suite

   ```
   ./hats-smoke.sh MYCLOUD XYZ
   ```

### Current smoke tests


- **ping hosts** ping the needed host(s)
- **test HDFS** create a folder on the Hadoop filesystem and upload some data
- **test MapReduce** run a simple MapReduce job (with `mapred streaming`)
- **test examples** run examples from the official distribution 
    - pi (MapReduce)
    - terasort (MapReduce)
    - JavaDecisionTreeRegressionExample (Spark)
    - JavaRandomForestRegressorExample (Spark)
    - JavaKMeansExample (Spark)
- **test configuration** test the local configuration files

