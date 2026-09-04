/*
 * Switches the font of the on-screen message windows in a client's interface.xdat.
 *
 * OnScreenMessageWnd1..8 are the eight slots ExShowScreenMessage lands in. Their big text boxes ask for
 * fontType LargeFontType_4, which is not a font of its own : the client resolves LargeFontType_1..4 to the
 * TrueType fonts declared in TTFontInfo.ini under the usages zonetitle / benchmark / broadcast1 / broadcast2.
 * broadcast2 is commented out in an international client, so those boxes fall back to a GDI default that
 * draws Latin and nothing else - a Cyrillic message shows an empty line. The bitmap fonts the rest of the
 * interface uses come from Localization.ini and do carry U+0401..U+044F, which is why the same text is
 * readable in chat. So the fix is to point the boxes at one of those instead.
 *
 * The small variants (TextBoxsm*, used when the server asks for the small size) already sit on Normal and
 * are left alone.
 *
 * Runs on the XDAT Editor's own libraries, so the file is parsed and rewritten by the same code the editor
 * uses. The ct0 schema is the one that reads an Interlude interface.xdat end to end.
 *
 * Usage:
 *   java -cp <editor jars> groovy.ui.GroovyMain screen_message_font.groovy <in.xdat> <out.xdat> [fontType]
 *
 * fontType defaults to SpecialBigerFont (the large bitmap font, Localization.ini's Font2). Normal is the
 * smaller one the chat window draws with.
 */

if (args.length < 2) {
    println 'usage: screen_message_font.groovy <in.xdat> <out.xdat> [fontType]'
    return
}

def src = new File(args[0])
def dst = new File(args[1])
def wanted = args.length > 2 ? args[2] : 'SpecialBigerFont'

def fontField = { obj ->
    def k = obj.getClass()
    while (k != null) {
        def f = k.declaredFields.find { it.name == 'fontType' }
        if (f != null) { f.accessible = true; return f }
        k = k.superclass
    }
    null
}

// The schema exposes fontType either as an int or as an enum, depending on its version. Take whichever.
def coerce = { field, String name ->
    if (field.type.isEnum()) {
        def v = field.type.enumConstants.find { it.name() == name }
        if (v == null) throw new IllegalArgumentException("unknown fontType '${name}', known: ${field.type.enumConstants*.name()}")
        return v
    }
    def known = ['Normal', 'SpecialBigerFont', 'SpecialDigitSmall', 'SpecialDigitNormal', 'SpecialDigitLarge',
                 'LargeFontType_1', 'LargeFontType_2', 'LargeFontType_3', 'LargeFontType_4']
    def i = known.indexOf(name)
    if (i < 0) throw new IllegalArgumentException("unknown fontType '${name}', known: ${known}")
    return i
}

def readXdat = { File f ->
    def x = new ct0.XDAT()
    long consumed = 0
    f.withInputStream { input ->
        def counting = new java.io.FilterInputStream(input) {
            int read() { def b = super.read(); if (b >= 0) consumed++; b }
            int read(byte[] b, int off, int len) { def n = super.read(b, off, len); if (n > 0) consumed += n; n }
        }
        x.read(counting)
    }
    if (consumed != f.length()) throw new IllegalStateException("${f}: parsed ${consumed} of ${f.length()} bytes")
    x
}

// A rewrite that changes nothing has to reproduce the file byte for byte, or nothing below can be trusted.
def xdat = readXdat(src)
def probe = File.createTempFile('xdat-roundtrip', '.xdat')
try {
    probe.withOutputStream { xdat.write(it) }
    if (probe.bytes != src.bytes)
        throw new IllegalStateException("a no-op rewrite of ${src} does not reproduce it - the schema does not fit this client")
} finally {
    probe.delete()
}
println "round trip: ${src} reproduced byte for byte (${src.length()} bytes, ${xdat.windows.size()} windows)"

def targets = []
xdat.windows.findAll { it.name ==~ /OnScreenMessageWnd\d+/ }.each { w ->
    w.children.each { c ->
        if (c.getClass().simpleName != 'TextBox') return
        if (c.name.startsWith('TextBoxsm')) return          // the small variant is already on a bitmap font
        targets << [window: w.name, box: c, field: fontField(c)]
    }
}
if (targets.isEmpty()) throw new IllegalStateException('no OnScreenMessageWnd text boxes found')

def value = coerce(targets[0].field, wanted)
println "changing ${targets.size()} text boxes to ${wanted}"
targets.each { t ->
    println "  ${t.window}.${t.box.name} : ${t.field.get(t.box)} -> ${wanted}"
    t.field.set(t.box, value)
}

dst.withOutputStream { xdat.write(it) }

// fontType is one int per box and every value here fits in a byte, so exactly one byte per box may move.
def a = src.bytes
def b = dst.bytes
if (a.length != b.length) throw new IllegalStateException("size changed: ${a.length} -> ${b.length}")
def diff = (0..<a.length).findAll { a[it] != b[it] }
println "written: ${dst} (${b.length} bytes, ${diff.size()} bytes differ)"
if (diff.size() != targets.size())
    throw new IllegalStateException("expected ${targets.size()} changed bytes, got ${diff.size()}")

// And it still has to parse to the last byte, with the new value in place.
def check = readXdat(dst)
check.windows.findAll { it.name ==~ /OnScreenMessageWnd\d+/ }.each { w ->
    w.children.each { c ->
        if (c.getClass().simpleName != 'TextBox') return
        def f = fontField(c)
        println "verify: ${w.name}.${c.name} = ${f.get(c)}"
    }
}
