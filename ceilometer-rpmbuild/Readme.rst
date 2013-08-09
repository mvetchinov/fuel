RPM BUILD:

1) Put ceilometer sources to the folder called ceilometer-2013.1.3. Make a tarball from ceilometer source. 
   tar -cvzf ceilometer-rpmbuild/SOURCES/ceilometer-2013.1.3.tar.gz ceilometer-2013.1.3

2) Set correct path to BUILDROOT in ceilometer-rpmbuild/SPECS/openstack-ceilometer.spec

2) Build RPMs:
   rpmbuild -ba ceilometer-rpmbuild/SPECS/openstack-ceilometer.spec
