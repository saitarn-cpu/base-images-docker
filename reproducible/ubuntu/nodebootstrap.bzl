# Copyright 2017 Google Inc. All rights reserved.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Rule for building nodejs installable tarball"""

def _impl(ctx):
    # Strip off the '.tar'
    image_name = ctx.attr._builder_image.label.name.split('.', 1)[0]
    # docker_build rules always generate an image named 'bazel/$package:$name'.
    builder_image_name = "bazel/%s:%s" % (ctx.attr._builder_image.label.package,
                                          image_name)

    # Generate a shell script to run the build.
    build_contents = """\
#!/bin/bash
set -ex

# Execute the image loader
{0}
# Run the builder image.
cid=$(docker run -d --privileged {1})
docker attach $cid
# Copy out the nodejs tar.
docker cp $cid:/workspace/nodejs.tar.gz {2}

# Cleanup
docker rm $cid
 """.format(ctx.executable._builder_image.path,
            builder_image_name,
            ctx.outputs.out.path)
    script = ctx.new_file(ctx.label.name + ".build")
    ctx.file_action(
        output=script,
        content=build_contents
    )

    ctx.actions.run(
        outputs=[ctx.outputs.out],
        inputs=ctx.attr._builder_image.files.to_list() +
        ctx.attr._builder_image.data_runfiles.files.to_list() + ctx.attr._builder_image.default_runfiles.files.to_list(),
        executable=script,
    )

    return struct()

nodebootstrap = rule(
    attrs = {
        "_builder_image": attr.label(
            default = Label("//reproducible/ubuntu:nodejs_builder"),
            allow_files = True,
            single_file = True,
            executable = True,
            cfg = "target",
        ),
    },
    executable = False,
    outputs = {
        "out": "%{name}.tar.gz",
    },
    implementation = _impl,
)

load(
    "@io_bazel_rules_docker//docker:docker.bzl",
    "docker_build",
)

def nodebootstrap_image(name, env=None):
    if not env:
        env = {}
    nodejs = "%s.nodejs" % name
    nodebootstrap(
        name=nodejs,
    )
    tars = [nodejs]
    docker_build(
        name=name,
        tars=tars,
        env=env,
        cmd="/bin/bash",
    )
