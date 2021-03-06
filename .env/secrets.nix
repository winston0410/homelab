let
  rsa =
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCasjsglbprqukxwJyhHDvY7MtFL+aa7RXKz7zzuh0dhHQmgtzCSc1R7NXoCrSx9SCgCX8IIkdoJzfkS4a02uK/XPzenXta3csEvsuOocOxvdGNHZs1qdIf15cn4GdmXjahMd7PM+QLF4zHZZVUKBxmZMQS8oJVc4fEGm0nmBdvLHW8IjT0gp4DhIl9RVWXuLg47++b73MbER/HJ4p096cstPh71EQUliGWYu2kJPUBvzs5vLektWbd6cqGP6U1ml+bctg0Hs7xm2JkMVRfT5j0D/sqr1s9d3+hbIYv7i0g8VFJ7777CVXe+3eHB0oSbA6eK4ZioLaSRnCxYX7IXMifPErnWLkhRVzgIHBvW2B29Eqr0HHsuac9Agx7GrKmWXgCPOLis0ddsjdnc3bP7FdBY5kfNWX1017pXSfrZLe0CGofOjw8YNC1UQwk8pDDMQ6+0rX3QGCMXoEAm4QmBwMTYTeboKZciDax3/oOYg6nr2lFFLeGOgD1kM+hzyZiCF+XjIljnXkzKEnZ6wQ1QcIMnmz20lVjh3b7KcYA82s8vTpDIaZFWPvcFrLiVRA2Rr3H14Kks3YlIy1/r0SlhZX410aCi44ndewLNEIm+tYEOWkdZo8B8I9B63DzNsMW6FmZJ859QkQYr0OpZ+QTQx8CipODD5m2CUmJ1Z/mTeM68Q==";

  ed25519 =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJl2J7tX28GcvnBwzPIpOzElMMApdXz/pPm4wXxIg41i";

  keyList = [ rsa ed25519 ];
in {
  "./netcup/life-builder.age".publicKeys = keyList;
  "./netcup/otp-server.age".publicKeys = keyList;
  "restic-repository-passwd.age".publicKeys = keyList;
  "calendso.age".publicKeys = keyList;
}
