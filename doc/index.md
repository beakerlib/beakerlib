# BeakerLib

After fedorahosted.org got shut down this became the official new home for this project.

BeakerLib is a shell-level integration testing library, providing
convenient functions which simplify writing, running and analysis of
integration and blackbox tests.

:::{toctree}
---
maxdepth: 2
titlesonly: true
caption: Contents
glob: true
---
manual
roadmap
:::

## News
### 2022-10-20
  * Released [version 1.29.3](https://github.com/beakerlib/beakerlib/releases/tag/1.29.3)
    - support for fmf_id nick attribute

### 2022-08-25
  * Released [version 1.29.2](https://github.com/beakerlib/beakerlib/releases/tag/1.29.2)
    - improved performance and memory consumption of the fingerprint feature

### 2022-07-19
  * Released [version 1.29.1](https://github.com/beakerlib/beakerlib/releases/tag/1.29.1)
    - fixed a check for os-release file existence

### 2022-06-29
  * Released [version 1.29](https://github.com/beakerlib/beakerlib/releases/tag/1.29)
    - rlImport: upwards traversal start in the current directory
    - rlImport: support '.' to import lib.sh from the current directory
    - rlImport: can handle libraries required by the fmf_id in different forms than (url, name)
      also name-only. Also the path attribute is considered
    - fingerprint: an asserts fingerprint and phases fingerprint is computed
      it is printed as a message and it is also available in the TestResults file
    - fixed LOG_LEVEL usage
    - removed dependency on selinuxenabled
    - fixed a few typos, thanks to jwakely@fedoraproject.org

### 2021-11-09
  * Released [version 1.28](https://github.com/beakerlib/beakerlib/releases/tag/1.28)
    - cleanup rlRun_LOG files at rlJournalEnd
    - close journal in rlDie - generate journal.xml at that moment
    - implemented functions rlIsOS, rlIsOSLike, rlIsOSVersion, and rlIsRHELLike
    - rlAssertRequired can now handle versioned dependencies
    - new functions rlCheckRerquired, rlCheckRecommended, and rlCheckDependencies

### 2021-03-25
  * Released [version 1.27](https://github.com/beakerlib/beakerlib/releases/tag/1.27)
    - rlCheckRequirements is now able to check also versioned requirements

### 2021-03-09
  * Released [version 1.26](https://github.com/beakerlib/beakerlib/releases/tag/1.26)
    - fixed rlServiceDisable if called without rlServiceEnable beforehand
    - few internal fixes

### 2021-02-09
  * Released [version 1.25](https://github.com/beakerlib/beakerlib/releases/tag/1.25)
    * rebased yash to version 1.2, fixes the backtick iterpretation
    * docs fixes, by Štěpán Němec <snemec@redhat.com>

### 2021-01-30
  * Released [version 1.24](https://github.com/beakerlib/beakerlib/releases/tag/1.24)
    * rlImport --all imports only required libraries, not recommend
    * implemented chkconfig fallback to systemctl
    * fixed `make test` test suite execution

### 2021-01-26
  * Released [version 1.23](https://github.com/beakerlib/beakerlib/releases/tag/1.23)
    * TestResults state indicator
    * profiling code
    * rebased yash to 1.1
    * fixed rlAssertLesser
    * fixed failed library load name logging

### 2021-01-20
  * Released [version 1.22](https://github.com/beakerlib/beakerlib/releases/tag/1.22)
    * There is finally a new stable release after a lot time.
    * ability to parse yaml files including main.fmf and metadata.yaml
    * ability the use simpler library name - library(foo)
    * ability to refer library using fmf id - {url: '../foo.git', name: '/'}, meaming the library is n the root folder
    * ability to put library even deeper in the tree - library(foo/path/to/the/library), {url: '../foo.git', name: '/path/to/the/library'}
    * better and more consistent search for libraries
    * docs update
    * some optimizations
    * for more info see individual commits

### 2019-06-13
  * Released [version 1.18.1](https://github.com/beakerlib/beakerlib/releases/tag/1.18.1)
    * introducing few bug fixes and better alignment to harness API

### 2019-04-04
  * Released [version 1.18](https://github.com/beakerlib/beakerlib/releases/tag/1.18)

### 2018-11-20
  * merged devel into testing branch

### 2018-03-26
  * draft of [[roadmap|roadmap]]

### 2018-01-26
  * as a part of the journal redesign we also changed the look

    it would be good to have some more opinions on this topic, please comment in [PR23](https://github.com/beakerlib/beakerlib/pull/23)
### 2018-01-25
  * we need to limit the number of ways how to do reboot in the test,
    therefore we would like to gather examples of tests with reboot, i.e. the sequence of beakerlib commands and their embedding to conditions, like:
    ```
    if [ "$REBOOTCOUNT" -eq 0 ]; then
      rlPhaseStartSetup 'first phase'
      rlPhaseEnd
      reboot; #actual reboot
    else
      rlPhaseStartSetup 'second phase'
      rlPhaseEnd
    fi
    ```
    Please put your templates into [this pad](https://public.etherpad-mozilla.org/p/beakerlib-reboot)

### 2017-12-14
  * new version [beakerlib-1.17.2](https://github.com/beakerlib/beakerlib/releases/tag/beakerlib-1.17.2) ready
    ```
    changelog:
     added result file
     fixes regarding changes IFS
     improved performance of xml journal processing which contains really big log messages
     enable nested phases by default
     fixed pre-phase reports generation
     other minor fixes and tweaks
    ```

### 2017-10-06
  * rename initiative [discussion pad](https://public.etherpad-mozilla.org/p/beakerlib-rename)


## Documentation
Manual pages which are also distributed within the Fedora package can be found [[here|man]].

## Bugs
[List of open bugs](https://bugzilla.redhat.com/buglist.cgi?bug_status=NEW&bug_status=ASSIGNED&bug_status=POST&bug_status=MODIFIED&bug_status=ON_DEV&bug_status=ON_QA&bug_status=VERIFIED&bug_status=RELEASE_PENDING&component=beakerlib&list_id=8030834&product=Fedora)

If you face and issue for which is not open a bug already you can proceed:<BR>
[file a new bug page](https://bugzilla.redhat.com/enter_bug.cgi?product=Fedora&component=beakerlib) can be use for reporting bugs or requesting a RFEs
