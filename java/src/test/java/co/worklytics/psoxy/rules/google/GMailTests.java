package co.worklytics.psoxy.rules.google;

import co.worklytics.psoxy.Sanitizer;
import co.worklytics.psoxy.impl.SanitizerImpl;
import co.worklytics.test.TestUtils;
import com.google.api.client.http.GenericUrl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

public class GMailTests {

    SanitizerImpl sanitizer;

    @BeforeEach
    public void setup() {
        sanitizer = new SanitizerImpl(Sanitizer.Options.builder()
            .rules(PrebuiltSanitizerRules.GMAIL)
            .build());
    }


    @Test
    void sanitize() {

        String jsonPart = "{\n" +
            "        \"name\": \"To\",\n" +
            "        \"value\": \"ops@worklytics.co\"\n" +
            "      }";

        String jsonString = new String(TestUtils.getData("api-response-examples/g-workspace/gmail/message.json"));

        //verify precondition that example actually contains something we need to pseudonymize
        assertTrue(jsonString.contains(jsonPart));
        assertTrue(jsonString.contains("erik@worklytics.co"));
        assertTrue(jsonString.contains("Subject"));

        String sanitized = sanitizer.sanitize(new GenericUrl("https://gmail.googleapis.com/gmail/v1/users/me/messages/17c3b1911726ef3f\\?format=metadata"), jsonString);


        //email address should disappear
        assertFalse(sanitized.contains(jsonPart));
        assertFalse(sanitized.contains(jsonPart.replaceAll("\\s", "")));
        assertFalse(sanitized.contains("erik@worklytics.co"));

        //redaction should remove 'Subject' header entirely; and NOT just replace it with `null`
        assertFalse(sanitized.contains("Subject"));
        assertFalse(sanitized.contains("null"));
    }
}
