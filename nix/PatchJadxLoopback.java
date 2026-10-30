import java.nio.file.Files;
import java.nio.file.Path;
import jdk.internal.org.objectweb.asm.ClassReader;
import jdk.internal.org.objectweb.asm.ClassVisitor;
import jdk.internal.org.objectweb.asm.ClassWriter;
import jdk.internal.org.objectweb.asm.MethodVisitor;
import jdk.internal.org.objectweb.asm.Opcodes;

/** Restrict the plugin's existing Javalin listener to IPv4 loopback. */
public class PatchJadxLoopback {
    public static void main(String[] args) throws Exception {
        ClassReader reader = new ClassReader(Files.readAllBytes(Path.of(args[0])));
        ClassWriter writer = new ClassWriter(ClassWriter.COMPUTE_MAXS);
        int[] replacements = {0};
        reader.accept(new ClassVisitor(Opcodes.ASM8, writer) {
            @Override
            public MethodVisitor visitMethod(int access, String name, String descriptor,
                    String signature, String[] exceptions) {
                MethodVisitor delegate = super.visitMethod(access, name, descriptor, signature, exceptions);
                return new MethodVisitor(Opcodes.ASM8, delegate) {
                    @Override
                    public void visitMethodInsn(int opcode, String owner, String method,
                            String desc, boolean isInterface) {
                        String server = "com/zin/jadxaimcp/deps/javalin/Javalin";
                        if (opcode == Opcodes.INVOKEVIRTUAL && owner.equals(server)
                                && method.equals("start") && desc.equals("(I)L" + server + ";")) {
                            // Existing stack: server, port. Add host, then swap to server, host, port.
                            super.visitLdcInsn("127.0.0.1");
                            super.visitInsn(Opcodes.SWAP);
                            super.visitMethodInsn(opcode, owner, method,
                                    "(Ljava/lang/String;I)L" + server + ";", isInterface);
                            replacements[0]++;
                        } else {
                            super.visitMethodInsn(opcode, owner, method, desc, isInterface);
                        }
                    }
                };
            }
        }, 0);
        if (replacements[0] != 1) {
            throw new IllegalStateException("Expected one listener call, found " + replacements[0]);
        }
        Files.write(Path.of(args[1]), writer.toByteArray());
    }
}
