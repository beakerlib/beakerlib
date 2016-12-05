" Vim syntax file
" Application: BeakerLib
" Maintainer: Jakub Prokeš
" Latest Revision: 13 Oct 2015

if exists("b:current_syntax")
  finish
endif

runtime! syntax/sh.vim

" Define keywords
syn keyword blJournalKeyword rlJournalStart rlJournalEnd rlJournalPrint rlJournalPrintText nextgroup=syntaxElement2 rlGetPhaseState rlGetTestState
syn keyword blPhasesKeyword rlPhaseStart rlPhaseEnd rlPhaseStartSetup rlPhaseStartTest rlPhaseStartCleanup
syn keyword blLoggingKeyword rlLog rlLogDebug rlLogInfo rlLogWarning rlLogError rlLogFatal rlDie rlBundleLogs rlFileSubmit
syn keyword blMainKeyword rlWatchdog rlReport rlCmpVersion rlTestVersion
syn keyword blBackupKeyword rlFileBackup rlFileRestore
syn keyword blAssertKeyword rlAssert0 rlAssertEquals rlAssertNotEquals rlAssertGreater rlAssertGreaterOrEqual rlAssertExists rlAssertNotExists rlAssertGrep rlAssertNotGrep rlAssertDiffer rlAssertNotDiffer rlFail rlPass
syn keyword blServicesKeyword rlServiceStart rlServiceStop rlServiceRestore
syn keyword blrpmKeyword rlCheckRpm rlAssertRpm rlAssertNotRpm rlAssertBinaryOrigin rlCheckMakefileRequires rlCheckRequirements rlGetMakefileRequires
syn keyword blMountKeyword rlMount rlCheckMount rlAssertMount rlAnyMounted rlHash rlUnhash
syn keyword blInfoKeyword rlShowPackageVersion rlGetArch rlGetDistroRelease rlGetDistroVariant rlShowRunningKernel rlGetPrimaryArch rlGetSecondaryArch
syn keyword blMetricKeyword rlLogMetricLow rlLogMetricHigh
syn keyword blTimeKeyword rlPerfTime_RunsInTime rlPerfTime_AvgFromRuns
syn keyword blXserverKeyword rlVirtualXStart rlVirtualXGetDisplay rlVirtualXStop rlVirtXGetCorrectID rlVirtXGetPid rlVirtXStartDisplay
syn keyword blCleanupKeyword rlCleanupAppend rlCleanupPrepend
syn keyword blAnalyzeKeyword rlDejaSum rlImport
syn keyword blReleaseKeyword rlIsFedora rlIsRHEL rlIsCentOS
syn keyword blSELINUXKeyword rlSEBooleanOff rlSEBooleanOn rlSEBooleanRestore
syn keyword blPSyncKeyword rlWait rlWaitForCmd rlWaitForFile rlWaitForSocket

syn cluster blAll contains=blJournalKeyword,blPhasesKeyword,blLoggingKeyword,blMainKeyword,blBackupKeyword,blAssertKeyword,blServicesKeyword,blrpmKeyword,blMountKeyword,blInfoKeyword,blMetricKeyword,blTimeKeyword,blXserverKeyword,blCleanupKeyword,blAnalyzeKeyword,blReleaseKeyword,blSELINUXKeyword,blPSyncKeyword

" highlight BeakerLib kyewords in loops,if,case and function blocks too
syn cluster shLoopList  add=@blAll,blrlRun
syn cluster shFunctionList add=@blAll,blrlRun
syn cluster shCaseEsacList add=@blAll,blrlRun
syn cluster shCaseList add=@blAll,blrlRun

" highlight Journal block
syn region blJournal matchgroup=blJournalKeyword start=/rlJournalStart/ end=/rlJournalEnd/ transparent

" highlight Phases block
syn region blPhases matchgroup=blPhasesKeyword start=/rlPhaseStart\(Setup\|Test\|Cleanup\)\?/ end=/rlPhaseEnd/ nextgroup=blPhasesType skipwhite transparent
syn match blPhasesType /\(FAIL\|WARN\)/

if exists("bl_rlRun_sub")
    " highlight first argument of rlRun as sub-command
    syn match blrlRun /rlRun/ nextgroup=blrlRunArgs skipwhite
    syn match blrlRunArgs /-t\|-l\|-c\|-s\|[^"\\]\+/ nextgroup=blCommandSub skipwhite contained
    syn region blCommandSub matchgroup=shCmdSubRegion start=/"/ skip='\\\\\|\\.' end=/"/ contained contains=@shCommandSubList,@blAll
else
    syn keyword blAssertKeyword rlRun rlAssert0 rlAssertEquals rlAssertNotEquals rlAssertGreater rlAssertGreaterOrEqual rlAssertExists rlAssertNotExists rlAssertGrep rlAssertNotGrep rlAssertDiffer rlAssertNotDiffer rlFail rlPass
endif



hi def link blCommandSub			blPlain
hi def link blJournalKeyword		blStatement
hi def link blJournal				blPlain
hi def link blPhasesKeyword			blStatement
hi def link blPhases				blPlain
hi def link blrlRunArgs				blrlRun
hi def link blrlRun					blIdentifier
hi def link blPhasesType			blType
hi def link blLoggingKeyword 		blIdentifier
hi def link blMainKeyword			blIdentifier
hi def link blBackupKeyword			blIdentifier
hi def link blAssertKeyword			blIdentifier
hi def link blServicesKeyword		blIdentifier
hi def link blrpmKeyword 			blIdentifier
hi def link blMountKeyword			blIdentifier
hi def link blInfoKeyword			blIdentifier
hi def link blMetricKeyword			blIdentifier
hi def link blTimeKeyword			blIdentifier
hi def link blXserverKeyword 		blIdentifier
hi def link blType					Type
hi def link blPlain					plain
hi def link blIdentifier			Function
hi def link blStatement				Statement
