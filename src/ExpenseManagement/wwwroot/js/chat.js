// Message Orchestrator - Neural Conversation Interface
// Unique implementation for AI chat functionality

class MessageOrchestrator {
    constructor() {
        this.transcriptViewport = null;
        this.composerField = null;
        this.transmitButton = null;
    }

    initialize() {
        this.transcriptViewport = document.getElementById('transcriptViewport');
        this.composerField = document.getElementById('userMessageComposer');
        this.transmitButton = document.getElementById('transmitMessageButton');

        if (!this.transcriptViewport || !this.composerField || !this.transmitButton) {
            return;
        }

        this.transmitButton.addEventListener('click', () => this.handleMessageTransmission());
        
        this.composerField.addEventListener('keydown', (keyEvent) => {
            if (keyEvent.key === 'Enter' && !keyEvent.shiftKey) {
                keyEvent.preventDefault();
                this.handleMessageTransmission();
            }
        });
    }

    async handleMessageTransmission() {
        const userQuery = this.composerField.value.trim();
        
        if (!userQuery) {
            return;
        }

        this.composerField.value = '';
        this.composerField.disabled = true;
        this.transmitButton.disabled = true;

        this.appendUserTransmission(userQuery);
        this.displayProcessingIndicator();

        try {
            const aiResponse = await this.transmitToNeuralEngine(userQuery);
            this.removeProcessingIndicator();
            this.appendAiResponse(aiResponse);
        } catch (anomaly) {
            this.removeProcessingIndicator();
            this.appendAiResponse('I encountered a communication error. Please try again.');
            console.error('Neural transmission failed:', anomaly);
        } finally {
            this.composerField.disabled = false;
            this.transmitButton.disabled = false;
            this.composerField.focus();
        }
    }

    async transmitToNeuralEngine(userQuery) {
        const transmissionPacket = {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ message: userQuery })
        };

        const serverResponse = await fetch('/api/chat', transmissionPacket);
        
        if (!serverResponse.ok) {
            throw new Error(`Server response: ${serverResponse.status}`);
        }

        const responsePayload = await serverResponse.json();
        return responsePayload.response || 'No response received';
    }

    appendUserTransmission(messageText) {
        const messageElement = document.createElement('div');
        messageElement.className = 'user-transmission-message';
        
        const avatarElement = document.createElement('div');
        avatarElement.className = 'message-avatar';
        avatarElement.textContent = '👤';
        
        const bubbleElement = document.createElement('div');
        bubbleElement.className = 'message-bubble';
        bubbleElement.textContent = messageText;
        
        messageElement.appendChild(avatarElement);
        messageElement.appendChild(bubbleElement);
        
        this.transcriptViewport.appendChild(messageElement);
        this.scrollToLatestMessage();
    }

    appendAiResponse(responseText) {
        const messageElement = document.createElement('div');
        messageElement.className = 'ai-response-message';
        
        const avatarElement = document.createElement('div');
        avatarElement.className = 'message-avatar';
        avatarElement.textContent = '🤖';
        
        const bubbleElement = document.createElement('div');
        bubbleElement.className = 'message-bubble';
        bubbleElement.innerHTML = this.transformMarkdownToHtml(this.sanitizeHtmlContent(responseText));
        
        messageElement.appendChild(avatarElement);
        messageElement.appendChild(bubbleElement);
        
        this.transcriptViewport.appendChild(messageElement);
        this.scrollToLatestMessage();
    }

    displayProcessingIndicator() {
        const indicatorElement = document.createElement('div');
        indicatorElement.className = 'ai-response-message processing-indicator';
        indicatorElement.id = 'processingIndicatorElement';
        
        const avatarElement = document.createElement('div');
        avatarElement.className = 'message-avatar';
        avatarElement.textContent = '🤖';
        
        const bubbleElement = document.createElement('div');
        bubbleElement.className = 'message-bubble';
        bubbleElement.textContent = 'Processing your request...';
        
        indicatorElement.appendChild(avatarElement);
        indicatorElement.appendChild(bubbleElement);
        
        this.transcriptViewport.appendChild(indicatorElement);
        this.scrollToLatestMessage();
    }

    removeProcessingIndicator() {
        const indicatorElement = document.getElementById('processingIndicatorElement');
        if (indicatorElement) {
            indicatorElement.remove();
        }
    }

    scrollToLatestMessage() {
        this.transcriptViewport.scrollTop = this.transcriptViewport.scrollHeight;
    }

    sanitizeHtmlContent(textContent) {
        const sanitizationMap = {
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#039;'
        };
        
        return textContent.replace(/[&<>"']/g, (matchedChar) => sanitizationMap[matchedChar]);
    }

    transformMarkdownToHtml(markdownText) {
        let transformedHtml = markdownText;
        
        // Transform **bold** to <strong>
        transformedHtml = transformedHtml.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
        
        // Transform *italic* to <em>
        transformedHtml = transformedHtml.replace(/\*(.+?)\*/g, '<em>$1</em>');
        
        // Transform bullet lists
        const lineSegments = transformedHtml.split('\n');
        let withinList = false;
        const processedLines = [];
        
        for (let idx = 0; idx < lineSegments.length; idx++) {
            const currentLine = lineSegments[idx];
            
            if (currentLine.trim().startsWith('- ') || currentLine.trim().startsWith('* ')) {
                if (!withinList) {
                    processedLines.push('<ul style="margin: 0.5rem 0; padding-left: 1.5rem;">');
                    withinList = true;
                }
                const itemContent = currentLine.trim().substring(2);
                processedLines.push(`<li>${itemContent}</li>`);
            } else {
                if (withinList) {
                    processedLines.push('</ul>');
                    withinList = false;
                }
                if (currentLine.trim()) {
                    processedLines.push(currentLine);
                }
            }
        }
        
        if (withinList) {
            processedLines.push('</ul>');
        }
        
        transformedHtml = processedLines.join('<br>');
        
        // Clean up multiple consecutive breaks
        transformedHtml = transformedHtml.replace(/(<br>){3,}/g, '<br><br>');
        
        return transformedHtml;
    }
}

// Global initialization function
function initializeNeuralConversationInterface() {
    const orchestrator = new MessageOrchestrator();
    orchestrator.initialize();
}

// Auto-initialize if elements are present
document.addEventListener('DOMContentLoaded', () => {
    if (document.getElementById('transcriptViewport')) {
        initializeNeuralConversationInterface();
    }
});
