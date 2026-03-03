kubectl edit vs patch vs apply vs replace
------------------------------------------------------------

This document explains the difference between ``kubectl edit``, 
``kubectl patch``, ``kubectl apply``, and ``kubectl replace``.

kubectl edit
------------

Opens the live Kubernetes resource in your default editor.
After saving, the updated configuration is sent back to the cluster.

Best for:
- Quick manual fixes
- One-off debugging changes

Not recommended for automation or CI/CD workflows.


kubectl patch
-------------

Applies a partial update to a resource by modifying only specific fields.
You provide only the fields that need to change.

Best for:
- Small targeted updates
- Scripts and automation
- Changing a single value (e.g., replicas)

Does not manage the full resource configuration.


kubectl apply
-------------

Creates or updates resources declaratively from a YAML or JSON file.
The cluster state is reconciled to match the file definition.

Best for:
- Infrastructure as Code
- GitOps workflows
- CI/CD pipelines
- Managing full resource configuration


kubectl replace
---------------

Replaces the entire resource definition using a YAML or JSON file.
The existing object is overwritten with the new definition.

Best for:
- Fully overwriting an existing resource
- Situations where you want exact file state without merge logic

Important:
- If fields are missing in the file, they are removed.
- Does not track last-applied configuration like ``apply``.
- Will fail if the resource does not already exist (unless using ``--force``).

Summary
-------

- Use ``edit`` for quick manual changes.
- Use ``patch`` for small targeted updates.
- Use ``apply`` for declarative configuration management.
- Use ``replace`` to completely overwrite a resource definition.