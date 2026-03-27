# Example Use Cases

## Investigating Pod Failures

```bash
argus-sre-agent --prompt "Our database pods are crash looping in production"
```

The agents collaborate to check pod status, analyze events, examine memory usage trends, and provide remediation steps.

## Diagnosing Performance Issues

```bash
argus-sre-agent --prompt "API response times have degraded 3x in the last hour"
```

The system correlates metrics across multiple dimensions to identify latency sources and configuration issues.

## Interactive Troubleshooting Session

```bash
argus-sre-agent --interactive

👤 You: We're seeing intermittent 502 errors from the payment service
🤖 Multi-Agent System: Investigating intermittent 502 errors...

👤 You: What's causing the queue buildup?
🤖 Multi-Agent System: Analyzing payment queue patterns...
```

Interactive mode allows multi-turn conversations for complex investigations.

## Proactive Monitoring

```bash
# Morning health check
argus-sre-agent --prompt "Perform a comprehensive health check of all production services"

# Capacity planning
argus-sre-agent --prompt "Analyze resource utilization trends and predict when we'll need to scale"

# Security audit
argus-sre-agent --prompt "Check for any suspicious patterns in authentication logs"
```

Examples of proactive monitoring and health check queries.