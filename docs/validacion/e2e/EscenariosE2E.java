package main.web.services.fitsense.e2e;

import main.web.services.fitsense.catalog.domain.exceptions.EmptyEligibleSetException;
import main.web.services.fitsense.planning.application.internal.generation.FirstPlanGenerationRunner;
import main.web.services.fitsense.planning.application.internal.generation.PipelineFirstPlanGenerationRunner;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.regex.Pattern;

/**
 * SOLO E2E LOCAL (no se versiona): envuelve el pipeline REAL con escenarios
 * elegidos por el correo del participante, para simular una IA lenta o caida.
 *   +d30 / +d90 / +d240 ...  espera N s y luego ejecuta el pipeline real
 *   +fallo                   falla siempre (error tecnico)
 *   +fallo1                  falla la primera ejecucion, despues pipeline real
 *   +nofactible              sin ejercicios elegibles (NO_FACTIBLE)
 * Sin etiqueta: pipeline real, sin demora.
 */
@Component
@Primary
public class EscenariosE2E implements FirstPlanGenerationRunner {

    private static final Logger log = LoggerFactory.getLogger(EscenariosE2E.class);
    private static final Pattern DEMORA = Pattern.compile("\\+d(\\d+)");
    private final PipelineFirstPlanGenerationRunner real;
    private final JdbcTemplate jdbc;
    private final java.util.Set<Long> yaFallaron = java.util.concurrent.ConcurrentHashMap.newKeySet();

    public EscenariosE2E(PipelineFirstPlanGenerationRunner real, JdbcTemplate jdbc) {
        this.real = real;
        this.jdbc = jdbc;
    }

    @Override
    public Long run(Long userId, Runnable beforePersist) {
        var email = jdbc.queryForObject("SELECT email FROM users WHERE user_id = ?", String.class, userId);
        log.info("[E2E] generacion para {} ({})", userId, email);
        var demora = DEMORA.matcher(email);
        if (demora.find()) {
            long s = Long.parseLong(demora.group(1));
            log.info("[E2E] demora simulada de la IA: {} s", s);
            try {
                Thread.sleep(s * 1000);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new IllegalStateException("interrumpida", e);
            }
        }
        if (email.contains("+nofactible")) throw new EmptyEligibleSetException(userId);
        if (email.contains("+fallo1") && yaFallaron.add(userId)) throw new IllegalStateException("[E2E] proveedor caido (1a vez)");
        if (email.contains("+fallo") && !email.contains("+fallo1")) throw new IllegalStateException("[E2E] proveedor caido");
        return real.run(userId, beforePersist);
    }
}
