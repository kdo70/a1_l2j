/*
 * Adds a "Repeat" button to ItemEnchantWnd in a client's interface.xdat.
 *
 * Runs on the XDAT Editor's own libraries (acmi's l2io / schema jars), so the file is parsed and rewritten by
 * the same code the editor uses rather than being patched by hand. The ct0 schema is the one that reads an
 * Interlude interface.xdat end to end - verified by a byte-identical read/write round-trip.
 *
 * The new button is a clone of btnOK, serialized and deserialized through the library itself so every field
 * it does not touch is reproduced exactly. The three buttons are then spread across the window's width.
 *
 * The caption is deliberately left empty: a Button's label is a system string id, and this client's
 * sysstring-e.dat is encrypted with a key the library does not carry. The script sets a tooltip instead, and
 * a TextBox can be laid over the button later if a visible label is wanted.
 *
 * Usage:
 *   java -cp <editor jars> groovy.ui.GroovyMain add_repeat_button.groovy <in.xdat> <out.xdat>
 */

if (args.length < 2) {
    println 'usage: add_repeat_button.groovy <in.xdat> <out.xdat>'
    return
}

def src = new File(args[0])
def dst = new File(args[1])

def xdat = new ct0.XDAT()
src.withInputStream { xdat.read(it) }

def wnd = xdat.windows.find { it.name == 'ItemEnchantWnd' }
if (wnd == null) throw new IllegalStateException('ItemEnchantWnd not found')

if (wnd.children.any { it.name == 'btnRepeat' }) {
    println 'btnRepeat already present - nothing to do'
    return
}

def ok = wnd.children.find { it.name == 'btnOK' }
def cancel = wnd.children.find { it.name == 'btnCancel' }
if (ok == null || cancel == null) throw new IllegalStateException('btnOK/btnCancel not found')

println "before: ${wnd.children*.name}"
println "  window ${wnd.size_absolute_width}x${wnd.size_absolute_height}"
println "  btnOK     ${ok.size_absolute_width}x${ok.size_absolute_height} at (${ok.anchor_x}, ${ok.anchor_y})"
println "  btnCancel ${cancel.size_absolute_width}x${cancel.size_absolute_height} at (${cancel.anchor_x}, ${cancel.anchor_y})"

// Clone btnOK through the library so untouched fields come out identical.
def buf = new ByteArrayOutputStream()
ok.write(buf)
def repeat = new ct0.Button().read(new ByteArrayInputStream(buf.toByteArray()))

repeat.name = 'btnRepeat'
repeat.buttonName = -1          // no system string: the caption is handled by the script

// Three buttons of the same width, evenly spread inside the window.
int w = ok.size_absolute_width
int total = wnd.size_absolute_width
int gap = 6
int margin = (int) ((total - (3 * w + 2 * gap)) / 2)
if (margin < 0) throw new IllegalStateException("three ${w}px buttons do not fit in ${total}px")

ok.anchor_x = margin
repeat.anchor_x = margin + w + gap
cancel.anchor_x = margin + 2 * (w + gap)
repeat.anchor_y = ok.anchor_y

// Keep the visual order OK / Repeat / Cancel in the child list too.
wnd.children.add(wnd.children.indexOf(cancel), repeat)

println "after:  ${wnd.children*.name}"
println "  btnOK     at (${ok.anchor_x}, ${ok.anchor_y})"
println "  btnRepeat at (${repeat.anchor_x}, ${repeat.anchor_y})"
println "  btnCancel at (${cancel.anchor_x}, ${cancel.anchor_y})"

dst.withOutputStream { xdat.write(it) }
println "written: ${dst} (${dst.length()} bytes, was ${src.length()})"

// Read the result back and confirm it still parses to the very last byte.
def check = new ct0.XDAT()
def consumed = 0L
dst.withInputStream { input ->
    def counting = new java.io.FilterInputStream(input) {
        int read() { def b = super.read(); if (b >= 0) consumed++; b }
        int read(byte[] b, int off, int len) { def n = super.read(b, off, len); if (n > 0) consumed += n; n }
    }
    check.read(counting)
}
def w2 = check.windows.find { it.name == 'ItemEnchantWnd' }
println "verify: ${check.windows.size()} windows, consumed ${consumed}/${dst.length()} bytes, children=${w2.children*.name}"
if (consumed != dst.length()) throw new IllegalStateException('the rewritten file does not parse cleanly')
