" Vim syntax file
" Application: BeakerLib
" Maintainer: Filip Holec
" Latest Revision: 22 Aug 2012

if exists("b:current_syntax")
  finish
endif

runtime! syntax/sh.vim

" Define keywords
syn keyword journalKeyword rlJournalStart rlJournalEnd rlJournalPrint rlJournalPrintText nextgroup=syntaxElement2
syn keyword phasesKeyword rlPhaseStart rlPhaseEnd rlPhaseStartSetup rlPhaseStartTest rlPhaseStartCleanup
syn keyword loggingKeyword rlLog rlLogDebug rlLogInfo rlLogWarning rlLogError rlLogFatal rlDie rlBundleLogs
syn keyword mainKeyword rlRun rlWatchdog rlReport
syn keyword backupKeyword rlFileBackup rlFileRestore
syn keyword assertKeyword rlAssert0 rlAssertEquals rlAssertNotEquals rlAssertGreater rlAssertGreaterOrEqual rlAssertExists rlAssertNotExists rlAssertGrep rlAssertNotGrep rlAssertDiffer rlAssertNotDiffer
syn keyword servicesKeyword rlServiceStart rlServiceStop rlServiceRestore
syn keyword rpmKeyword rlCheckRpm rlAssertRpm rlAssertNotRpm
syn keyword mountKeyword rlMount rlCheckMount rlAssertMount
syn keyword infoKeyword rlShowPackageVersion rlGetArch rlGetDistroRelease rlGetDistroVariant rlShowRunningKernel
syn keyword metricKeyword rlLogMetricLow rlLogMetricHigh
syn keyword timeKeyword rlPerfTime_RunsInTime rlPerfTime_AvgFromRuns
syn keyword xserverKeyword rlVirtualXStart rlVirtualXGetDisplay rlVirtualXStop

hi def link journalKeyword Type
hi def link phasesKeyword Type
hi def link loggingKeyword Type
hi def link mainKeyword Type
hi def link assertKeyword Type
hi def link backupKeyword Type
hi def link servicesKeyword Type
hi def link rpmKeyword Type
hi def link mountKeyword Type
hi def link infoKeyword Type
hi def link metricKeyword Type
hi def link timeKeyword Type
hi def link xserverKeyword Type
