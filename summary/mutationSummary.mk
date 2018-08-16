include usb-modules-v2/Makefile.inc
include usb-modules-v2/variant_callers/somatic/somaticVariantCaller.inc

LOGDIR = log/summary.$(NOW)

#.DELETE_ON_ERROR:
.SECONDARY: 
PHONY : mutation_summary

SUMMARY_PREFIX = summary/mutation_summary$(PROJECT_PREFIX).$(DOWNSTREAM_EFF_TYPES) summary/mutation_summary$(PROJECT_PREFIX).tab

ifeq ($(findstring EXCEL,$(MUTATION_SUMMARY_FORMAT)),EXCEL)
mutation_summary : $(foreach summary_prefix,$(SUMMARY_PREFIX),$(summary_prefix).xlsx)
endif
ifeq ($(findstring TXT,$(MUTATION_SUMMARY_FORMAT)),TXT)
mutation_summary : $(foreach summary_prefix,$(SUMMARY_PREFIX),$(summary_prefix).txt)
endif

ALLTABLES = $(foreach prefix,$(CALLER_PREFIX),\
	alltables/allTN$(PROJECT_PREFIX).$(call DOWMSTREAM_VCF_TABLE_SUFFIX,$(prefix)).txt)
ALLTABLES_ALLEFFTYPES = $(foreach prefix,$(CALLER_PREFIX),\
	alltables/allTN$(PROJECT_PREFIX).$(call DOWMSTREAM_VCF_TABLE_SUFFIX_ALLEFFTYPES,$(prefix)).txt)


summary/mutation_summary$(PROJECT_PREFIX).tab.xlsx : $(DOWMSTREAM_VCF_TABLE_SUFFIX_ALLEFFTYPES)
	$(call RUN,1,$(RESOURCE_REQ_HIGH_MEM),$(RESOURCE_REQ_MEDIUM),$(R_MODULE),"\
	$(MUTATION_SUMMARY_RSCRIPT) --outFile $(@) $(^)")

summary/mutation_summary$(PROJECT_PREFIX).$(DOWNSTREAM_EFF_TYPES).xlsx : $(ALLTABLES)
	$(call RUN,1,$(RESOURCE_REQ_HIGH_MEM),$(RESOURCE_REQ_MEDIUM),$(R_MODULE),"\
	$(MUTATION_SUMMARY_RSCRIPT) --outFile $(@) $(^)")

summary/mutation_summary$(PROJECT_PREFIX).tab.txt : $(DOWMSTREAM_VCF_TABLE_SUFFIX_ALLEFFTYPES)
	$(call RUN,1,$(RESOURCE_REQ_HIGH_MEM),$(RESOURCE_REQ_MEDIUM),$(R_MODULE),"\
	$(MUTATION_SUMMARY_RSCRIPT) --outFile $(@) $(^) --outputFormat TXT ")

summary/mutation_summary$(PROJECT_PREFIX).$(DOWNSTREAM_EFF_TYPES).txt : $(ALLTABLES)
	$(call RUN,1,$(RESOURCE_REQ_HIGH_MEM),$(RESOURCE_REQ_MEDIUM),$(R_MODULE),"\
	$(MUTATION_SUMMARY_RSCRIPT) --outFile $(@) $(^) --outputFormat TXT ")

summary/mutation_summary$(PROJECT_PREFIX).tab.detected.txt : $(DOWMSTREAM_VCF_TABLE_SUFFIX_ALLEFFTYPES)
	$(call RUN,1,$(RESOURCE_REQ_HIGH_MEM),$(RESOURCE_REQ_MEDIUM),$(R_MODULE),"\
	$(MUTATION_SUMMARY_RSCRIPT) --outFile $(@) $(^) --outputFormat TXT --filterFlags interrogation_Absent")

summary/mutation_summary$(PROJECT_PREFIX).tab.$(DOWNSTREAM_EFF_TYPES).detected.txt : $(ALLTABLES)
	$(call RUN,1,$(RESOURCE_REQ_HIGH_MEM),$(RESOURCE_REQ_MEDIUM),$(R_MODULE),"\
	$(MUTATION_SUMMARY_RSCRIPT) --outFile $(@) $(^) --outputFormat TXT --filterFlags interrogation_Absent")

