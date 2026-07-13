#!/bin/bash
set -euo pipefail

cd /app 2>/dev/null || cd /testbed 2>/dev/null

cat > solution_patch.diff << '__SOLUTION__'
diff --git a/message.go b/message.go
index f7ceb1d..f5ac864 100644
--- a/message.go
+++ b/message.go
@@ -24,6 +24,8 @@ const (
 	bitmapIdx = 1
 )
 
+type SpecSelector func(mti string) *MessageSpec
+
 type Message struct {
 	spec         *MessageSpec
 	cachedBitmap *field.Bitmap
@@ -33,6 +35,8 @@ type Message struct {
 
 	// stores all fields according to the spec
 	fields map[int]field.Field
+
+	specSelector SpecSelector
 }
 
 func NewMessage(spec *MessageSpec) *Message {
@@ -97,6 +101,26 @@ func (m *Message) GetSpec() *MessageSpec {
 	return m.spec
 }
 
+func (m *Message) SetSpecSelector(selector SpecSelector) {
+	m.mu.Lock()
+	defer m.mu.Unlock()
+	m.specSelector = selector
+}
+
+func (m *Message) GetSpecSelector() SpecSelector {
+	m.mu.Lock()
+	defer m.mu.Unlock()
+	return m.specSelector
+}
+
+func (m *Message) SetSpecMap(specMap map[string]*MessageSpec) {
+	m.mu.Lock()
+	defer m.mu.Unlock()
+	m.specSelector = func(mti string) *MessageSpec {
+		return specMap[mti]
+	}
+}
+
 func (m *Message) Field(id int, val string) error {
 	m.mu.Lock()
 	defer m.mu.Unlock()
@@ -334,6 +358,29 @@ func (m *Message) unpack(src []byte) (string, error) {
 
 	offset := read
 
+	// Dynamic spec selection based on MTI value if selector is registered
+	if m.specSelector != nil {
+		mtiVal, err := mti.String()
+		if err != nil {
+			return strconv.Itoa(mtiIdx), fmt.Errorf("failed to get MTI string value: %w", err)
+		}
+		if mtiVal == "" {
+			return strconv.Itoa(mtiIdx), fmt.Errorf("MTI field is empty, cannot select spec")
+		}
+		selectedSpec := m.specSelector(mtiVal)
+		if selectedSpec == nil {
+			return strconv.Itoa(mtiIdx), fmt.Errorf("no spec found for MTI %s", mtiVal)
+		}
+		// Validate selected spec
+		if err := selectedSpec.Validate(); err != nil {
+			return strconv.Itoa(mtiIdx), fmt.Errorf("selected spec for MTI %s is invalid: %w", mtiVal, err)
+		}
+		// Switch spec and reset bitmap cache to use new spec's bitmap definition
+		m.spec = selectedSpec
+		m.cachedBitmap = nil
+		m.resetBitmap()
+	}
+
 	// unpack Bitmap
 	read, err = m.bitmap().Unpack(src[offset:])
 	if err != nil {
@@ -429,6 +476,7 @@ func (m *Message) Clone() (*Message, error) {
 	newMessage := NewMessage(m.spec)
 
 	m.mu.Lock()
+	selector := m.specSelector
 	bytes, err := m.wrapErrorPack()
 	if err != nil {
 		m.mu.Unlock()
@@ -436,6 +484,10 @@ func (m *Message) Clone() (*Message, error) {
 	}
 	m.mu.Unlock()
 
+	if selector != nil {
+		newMessage.SetSpecSelector(selector)
+	}
+
 	mti, err := m.GetMTI()
 	if err != nil {
 		return nil, err
__SOLUTION__

git apply --verbose solution_patch.diff || patch --fuzz=5 -p1 -i solution_patch.diff
