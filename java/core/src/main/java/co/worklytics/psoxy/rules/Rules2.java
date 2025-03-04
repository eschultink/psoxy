package co.worklytics.psoxy.rules;


import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonPropertyOrder;
import lombok.*;
import lombok.extern.java.Log;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.List;

@Builder(toBuilder = true)
@Log
@AllArgsConstructor //for builder
@NoArgsConstructor //for Jackson
@Getter
@EqualsAndHashCode
@JsonPropertyOrder(alphabetic = true)
@JsonInclude(JsonInclude.Include.NON_NULL) //NOTE: despite name, also affects YAML encoding
public class Rules2 implements RuleSet, Serializable {


    private static final long serialVersionUID = 1L;

    /**
     * scopeId to set for any identifiers parsed from source that aren't email addresses
     *
     * NOTE: can be overridden by config, in case you're connecting to an on-prem / private instance
     * of the source and you don't want it's identifiers to be treated as under the default scope
     */
    @Getter
    String defaultScopeIdForSource;

    @Singular
    List<Endpoint> endpoints;

    @Builder.Default
    Boolean allowAllEndpoints = false;


    /**
     * add endpoints from other ruleset to this one
     * @param endpointsToAdd to be added
     * @return new ruleset based on this one, but with added endpoints
     */
    public Rules2 withAdditionalEndpoints(Endpoint... endpointsToAdd) {
        Rules2Builder builder = this.toBuilder();
        Arrays.stream(endpointsToAdd).forEach(builder::endpoint);
        return builder.build();
    }

    public Rules2 withAdditionalEndpoints(List<Endpoint> endpointsToAdd) {
        Rules2Builder builder = this.toBuilder();
        endpointsToAdd.forEach(builder::endpoint);
        return builder.build();
    }


    @JsonPropertyOrder(alphabetic = true)
    @Builder
    @AllArgsConstructor //for builder
    @NoArgsConstructor //for Jackson
    @Getter
    public static class Endpoint {

        String pathRegex;

        @JsonInclude(value=JsonInclude.Include.NON_EMPTY)
        @Singular
        List<Transform> transforms = new ArrayList<>();
    }


    //TODO: fix YAML serialization with something like
    // https://stackoverflow.com/questions/55878770/how-to-use-jsonsubtypes-for-polymorphic-type-handling-with-jackson-yaml-mapper


}
