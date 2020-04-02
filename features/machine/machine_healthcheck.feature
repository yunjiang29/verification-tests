Feature: MachineHealthCheck Test Scenarios

  # @author jhou@redhat.com
  # @case_id OCP-25897
  @admin
  @destructive
  Scenario: Remediation should be applied when the unhealthyCondition 'Ready' is met
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    Given I use the "openshift-machine-api" project
    And I clone a machineset named "machineset-25897"

    # Create MHC
    When I run oc create over "<%= BushSlicer::HOME %>/testdata/cloud/mhc/mhc1.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api       |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set.name %> |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set.cluster %>  |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set.name %>     |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set.name %>" machinehealthcheck is deleted after scenario

    # Create unhealthyCondition to trigger machine remediation
    When I create the 'Ready' unhealthyCondition
    Then the machine should be remediated

    # Verify when a machine is deleted, the node is drained(even if it's unreachable)
    Given a pod becomes ready with labels:
      | api=clusterapi, k8s-app=controller |
    When I run the :logs admin command with:
      | resource_name | <%= pod.name %>    |
      | c             | machine-controller |
    Then the output should contain:
      | Node "<%= machine.node_name %>" is unreachable, draining will wait |
      | drain successful for machine "<%= machine.name %>"                 |

  # @author jhou@redhat.com
  # @case_id OCP-26311
  @admin
  @destructive
  Scenario: Create a machinehealthcheck when there is already an unhealthy machine
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user

    Given I clone a machineset named "machineset-26311"

    # Create unhealthyCondition before createing a MHC
    Given I create the 'Ready' unhealthyCondition

    # Create MHC
    When I run oc create over "<%= BushSlicer::HOME %>/testdata/cloud/mhc/mhc1.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api       |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set.name %> |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set.cluster %>  |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set.name %>     |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set.name %>" machinehealthcheck is deleted after scenario

    Then the machine should be remediated

  # @author jhou@redhat.com
  # @case_id OCP-25734
  @admin
  @destructive
  Scenario: Create multiple MHCs to monitor same machineset
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user

    Given I clone a machineset named "machineset-25734"

    # Create MHCs
    Given I run the steps 2 times:
    """
    When I run oc create over "<%= BushSlicer::HOME %>/testdata/cloud/mhc/mhc1.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api                 |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set.name %>-#{ cb.i } |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set.cluster %>            |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set.name %>               |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set.name %>-#{ cb.i }" machinehealthcheck is deleted after scenario
    """

    # Create unhealthyCondition before createing a MHC
    When I create the 'Ready' unhealthyCondition
    Then the machine should be remediated

  # @author jhou@redhat.com
  # @case_id OCP-25691
  @admin
  @destructive
  Scenario: Use "maxUnhealthy" to prevent automated remediation
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    Given I store the number of machines in the :num_to_restore clipboard
    And admin ensures node number is restored to "<%= cb.num_to_restore %>" after scenario
    Given I use the "openshift-machine-api" project
    And I clone a machineset named "machineset-25691"

    # Create MHC
    When I run oc create over "<%= BushSlicer::HOME %>/testdata/cloud/mhc/mhc1.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api         |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set.name %>-1 |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set.cluster %>    |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set.name %>       |
      | ["spec"]["maxUnhealthy"]                                                           | 0                             |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set.name %>-1" machinehealthcheck is deleted after scenario
    When I run oc create over "<%= BushSlicer::HOME %>/testdata/cloud/mhc/mhc1.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api         |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set.name %>-2 |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set.cluster %>    |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set.name %>       |
      | ["spec"]["maxUnhealthy"]                                                           | 90%                           |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set.name %>-2" machinehealthcheck is deleted after scenario

    # Create unhealthyCondition to trigger machine remediation
    Given I create the 'Ready' unhealthyCondition
    Given a pod becomes ready with labels:
      | api=clusterapi, k8s-app=controller |
    And I wait up to 600 seconds for the steps to pass:
    """
    When I run the :logs admin command with:
      | resource_name | <%= pod.name %>                |
      | c             | machine-healthcheck-controller |
    Then the output should contain:
      | mhc-<%= machine_set.name %>-1: total targets: 1,  maxUnhealthy: 0, unhealthy: 1. Short-circuiting remediation   |
      | mhc-<%= machine_set.name %>-2: total targets: 1,  maxUnhealthy: 90%, unhealthy: 1. Short-circuiting remediation |
    """