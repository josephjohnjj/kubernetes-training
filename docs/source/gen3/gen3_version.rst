How the GEN3 2025.08 Release Was Selected
=========================================

The active deployment combines official Helm chart release ``0.2.21`` with the
GEN3 application release train ``2025.08``. The chart is vendored at
``charts/gen3-2025.08`` and the previous ``charts/gen3`` directory is retained
as a rollback reference.

Selection and import process
----------------------------

The reproducible workflow is:

#. Identify the required GEN3 application release, here ``2025.08``.
#. Locate the corresponding official GEN3 Helm chart release, here ``0.2.21``.
#. Download the exact chart archive, record its checksum, and extract it into a
   versioned directory.
#. Vendor all chart dependencies and retain ``Chart.lock``.
#. Pin each enabled GEN3 service image to ``2025.08``.
#. Apply only documented compatibility changes.
#. Validate the rendered chart and record the repository commit.

Example commands
----------------

Run these against the official GEN3 chart repository used by the project. The
repository name and URL must be recorded in the change ticket::

   helm repo add gen3 <OFFICIAL_GEN3_HELM_REPOSITORY_URL>
   helm repo update
   helm search repo gen3/gen3 --versions
   helm pull gen3/gen3 --version 0.2.21
   shasum -a 256 gen3-0.2.21.tgz
   tar -xzf gen3-0.2.21.tgz
   mv gen3 charts/gen3-2025.08
   helm dependency build charts/gen3-2025.08

Do not replace ``<OFFICIAL_GEN3_HELM_REPOSITORY_URL>`` by guessing. Recover it
from the original release record or an authoritative GEN3 source before
repeating the import. The current repository proves the chart version and lock
digest but does not record the original download URL or archive checksum.

Compatibility adjustments
-------------------------

The environment made four documented adjustments:

* Mount Indexd settings at ``/indexd/local_settings.py`` for the 2025.08 image.
* Pass Elasticsearch host, port, protocol, username, and password separately to
  Tube.
* Configure Guppy, Tube, and Portal to use ``dev_case`` consistently.
* Run an Argo CD PreSync Job that creates empty Elasticsearch indices before
  Guppy starts.

These changes are described in ``charts/gen3-2025.08/COMPATIBILITY.md`` and
were introduced by repository commit ``8dcfd53d7e090cbae86e481b6185af6f55770187``.

Validate the selected release
-----------------------------

::

   grep '^version:' charts/gen3-2025.08/Chart.yaml
   grep 'tag: "2025.08"' charts/gen3-2025.08/values/gen3-values.yaml
   helm dependency list charts/gen3-2025.08
   charts/gen3-2025.08/validate.sh
   git diff --exit-code charts/gen3-2025.08/Chart.lock

After deployment, compare runtime images with the expected release::

   kubectl -n gen3 get pods \
     -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.containers[*]}{.image}{" "}{end}{"\n"}{end}'

Reproducibility record
----------------------

For the next import, commit a small provenance file containing the upstream
repository URL, chart version, archive SHA-256, pull date, dependency lock
digest, application image digests, compatibility patches, and validation
results. That information is needed to prove that a later rebuild uses the same
artifacts rather than merely the same mutable tags.

