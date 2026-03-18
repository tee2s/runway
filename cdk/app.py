#!/usr/bin/env python3
from aws_cdk import App, Environment, Tags

from stacks.config import InfraConfig
from stacks.network_stack import NetworkStack
from stacks.storage_stack import StorageStack
from stacks.compute_stack import ComputeStack


app = App()
config = InfraConfig.from_app(app)

env = Environment(
    account=app.node.try_get_context("account"),
    region=app.node.try_get_context("region"),
)

network = NetworkStack(
    app,
    f"{config.project_name}-network",
    config=config,
    env=env,
)

storage = StorageStack(
    app,
    f"{config.project_name}-storage",
    config=config,
    env=env,
)

compute = ComputeStack(
    app,
    f"{config.project_name}-compute",
    config=config,
    vpc=network.vpc,
    gazebo_sg=network.gazebo_sg,
    isaac_sg=network.isaac_sg,
    bucket=storage.bucket,
    env=env,
)
compute.add_dependency(network)
compute.add_dependency(storage)

for stack in [network, storage, compute]:
    Tags.of(stack).add("Project", config.project_name)
    Tags.of(stack).add("ManagedBy", "cdk")
    Tags.of(stack).add("Workload", "robotics-sim")

app.synth()
