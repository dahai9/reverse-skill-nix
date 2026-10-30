import org.eclipse.swt.SWT;
import org.eclipse.swt.browser.Browser;
import org.eclipse.swt.browser.ProgressAdapter;
import org.eclipse.swt.browser.ProgressEvent;
import org.eclipse.swt.layout.FillLayout;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Shell;

/** Exercise JEB's bundled SWT and native WebKit, without contacting the network. */
public final class SwtBrowserSmoke {
    public static void main(String[] args) {
        Display display = new Display();
        try {
            Shell shell = new Shell(display);
            shell.setLayout(new FillLayout());
            shell.setSize(640, 480);
            Browser browser = new Browser(shell, SWT.WEBKIT);
            boolean[] completed = { false };
            browser.addProgressListener(new ProgressAdapter() {
                @Override
                public void completed(ProgressEvent event) {
                    completed[0] = true;
                }
            });
            shell.open();
            if (!browser.setText("<html><body>JEB WebKit smoke test</body></html>")) {
                throw new AssertionError("WebKit rejected local HTML");
            }
            long deadline = System.nanoTime() + 20_000_000_000L;
            while (!completed[0] && System.nanoTime() < deadline) {
                if (!display.readAndDispatch()) {
                    try {
                        Thread.sleep(10);
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                        throw new AssertionError(e);
                    }
                }
            }
            if (!completed[0]) {
                throw new AssertionError("WebKit did not finish loading local HTML");
            }
            System.out.println("SWT " + browser.getBrowserType() + " rendered local HTML");
            shell.dispose();
        } finally {
            display.dispose();
        }
    }
}
