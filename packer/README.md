# Building a Packer image

This packer template will use the Ubuntu 18.04 Canonical image as the base image. It will then install ansible to execute a playbook. This playbook will install and configure nginx web server to render a static webpage on port 8080.

## References:

1. https://docs.microsoft.com/en-us/azure/virtual-machines/linux/build-image-with-packer

2. https://code-maven.com/install-and-configure-nginx-using-ansible

3. https://www.w3.org/TR/html401/struct/global.html