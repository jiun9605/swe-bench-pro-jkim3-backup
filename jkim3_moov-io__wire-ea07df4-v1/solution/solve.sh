#!/bin/bash
set -euo pipefail

cd /app 2>/dev/null || cd /testbed 2>/dev/null

cat > solution_patch.diff << '__SOLUTION__'
diff --git a/fedWireMessage.go b/fedWireMessage.go
index 767ec4e..d499401 100644
--- a/fedWireMessage.go
+++ b/fedWireMessage.go
@@ -782,12 +782,27 @@ func (fwm *FEDWireMessage) validateServiceMessage() error {
 		return fieldError("TypeSubType", NewErrBusinessFunctionCodeProperty("TypeSubType", typeSubType,
 			fwm.BusinessFunctionCode.BusinessFunctionCode))
 	}
+	if err := fwm.checkMandatoryServiceMessageTags(); err != nil {
+		return err
+	}
 	if err := fwm.checkProhibitedServiceMessageTags(); err != nil {
 		return err
 	}
 	return nil
 }
 
+// checkMandatoryServiceMessageTags checks for the tags required by ServiceMessage BFC
+// ServiceMessage tag {9000} is mandatory and must contain at least LineOne.
+func (fwm *FEDWireMessage) checkMandatoryServiceMessageTags() error {
+	if fwm.ServiceMessage == nil {
+		return fieldError("ServiceMessage", ErrFieldRequired)
+	}
+	if strings.TrimSpace(fwm.ServiceMessage.LineOne) == "" {
+		return fieldError("ServiceMessage.LineOne", ErrFieldRequired)
+	}
+	if err := fwm.ServiceMessage.Validate(); err != nil {
+		return err
+	}
+	return nil
+}
+
 // checkProhibitedServiceMessageTags ensures there are no tags present in the message that are incompatible with the BFCServiceMessage code
 // Tags NOT permitted:
 //
__SOLUTION__

git apply --verbose solution_patch.diff || patch --fuzz=5 -p1 -i solution_patch.diff
