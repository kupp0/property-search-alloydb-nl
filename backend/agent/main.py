import os
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from agent import agent

from google.adk import Runner
from google.adk.sessions import InMemorySessionService

from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For development; restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Runner
# We need a session service. InMemory is fine for this demo/stateless usage.
session_service = InMemorySessionService()
runner = Runner(agent=agent, app_name="property_agent", session_service=session_service)

class ChatRequest(BaseModel):
    message: str
    session_id: str = "default_session"

class ChatResponse(BaseModel):
    response: str

@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    try:
        # Use Runner to execute the agent
        user_id = "default_user"
        session_id = request.session_id
        app_name = "property_agent"
        
        # Ensure session exists
        session = await session_service.get_session(app_name=app_name, user_id=user_id, session_id=session_id)
        if not session:

            await session_service.create_session(app_name=app_name, user_id=user_id, session_id=session_id)
        
        response_text = ""
        # Runner.run_async returns AsyncGenerator[Event, None]
        # We need to pass new_message as google.genai.types.Content
        
        from google.genai.types import Content, Part
        
        message = Content(role="user", parts=[Part(text=request.message)])
        
        async for event in runner.run_async(
            user_id=user_id,
            session_id=session_id,
            new_message=message
        ):
            # event might be a ModelResponse or similar
            # We need to extract text from event
            # Process event to extract text
            
            # Check if event has 'content' (ModelResponse)
            # or if it is a chunk of text.
            # Based on ADK, events can be diverse.
            # We look for ModelResponse or similar that has 'content'.
            # Or 'text' field.
            
            # Try to extract text from event if possible
            # We'll accumulate all text we find.
            if hasattr(event, 'content') and event.content:
                # content might be Content object
                for part in event.content.parts or []:
                    if part.text:
                        response_text += part.text
            elif hasattr(event, 'text') and event.text:
                response_text += event.text
            
        return ChatResponse(response=response_text or "Agent executed (no text response)")
    except Exception as e:
        import traceback
        traceback.print_exc()
        # Return the error message to the user instead of a 500 error
        # This allows the user to see why the tool failed (e.g., "Not enough info")
        return ChatResponse(response=f"I encountered an issue processing your request: {str(e)}")

@app.get("/health")
def health():
    return {"status": "ok"}

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)
