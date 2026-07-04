import { NextMessageInputOnPressEnterParameter } from '@/components/message-input/next';
import { MessageType } from '@/constants/chat';
import {
  useHandleMessageInputChange,
  useRegenerateMessage,
  useSelectDerivedMessages,
  useSendMessageWithSse,
} from '@/hooks/logic-hooks';
import { useGetChatSearchParams } from '@/hooks/use-chat-request';
import { IMessage } from '@/interfaces/database/chat';
import api from '@/utils/api';
import { trim } from 'lodash';
import { useCallback, useEffect, useState } from 'react';
import { useParams } from 'react-router';
import { v4 as uuid } from 'uuid';
import { useCreateConversationBeforeSendMessage } from './use-chat-url';
import { useFindPrologueFromDialogList } from './use-select-conversation-list';
import { useUploadFile } from './use-upload-file';
import { useImage2Text } from './use-image2text';

const IMAGE_FILE_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.webp'];

function isImageFile(file: File) {
  const mimeMatched = ['image/jpeg', 'image/png', 'image/webp'].includes(
    file.type,
  );

  const lowerName = file.name.toLowerCase();
  const extMatched = IMAGE_FILE_EXTENSIONS.some((ext) =>
    lowerName.endsWith(ext),
  );

  return mimeMatched || extMatched;
}

function buildImageRagQuestion(visionText: string, userQuestion: string) {
  return `用户上传了一张茶园或茶叶相关图片，视觉模型识别结果如下：

【图片识别结果】
${visionText}

【用户原问题】
${userQuestion}

请结合知识库内容回答。要求：
1. 先说明图片中可见现象；
2. 再结合茶园知识库判断可能原因；
3. 给出处理建议；
4. 如果无法确定，请说明还需要补充哪些信息。`;
}

export const useSelectNextMessages = () => {
  const {
    scrollRef,
    messageContainerRef,
    setDerivedMessages,
    derivedMessages,
    addNewestAnswer,
    addNewestQuestion,
    removeLatestMessage,
    removeMessageById,
    removeMessagesAfterCurrentMessage,
  } = useSelectDerivedMessages();
  const { isNew, conversationId } = useGetChatSearchParams();
  const { id: dialogId } = useParams();
  const prologue = useFindPrologueFromDialogList();

  const addPrologue = useCallback(() => {
    if (dialogId !== '' && isNew === 'true') {
      const nextMessage = {
        role: MessageType.Assistant,
        content: prologue,
        id: uuid(),
        conversationId: conversationId,
      } as IMessage;

      setDerivedMessages([nextMessage]);
    }
  }, [conversationId, dialogId, isNew, prologue, setDerivedMessages]);

  useEffect(() => {
    addPrologue();
  }, [addPrologue]);

  return {
    scrollRef,
    messageContainerRef,
    derivedMessages,
    addNewestAnswer,
    addNewestQuestion,
    removeLatestMessage,
    removeMessageById,
    removeMessagesAfterCurrentMessage,
    setDerivedMessages,
  };
};

export const useSendMessage = (controller: AbortController) => {
  const { conversationId, isNew } = useGetChatSearchParams();
  const { handleInputChange, value, setValue } = useHandleMessageInputChange();
  const [rawFiles, setRawFiles] = useState<File[]>([]);
  const { image2text, image2textLoading } = useImage2Text();

  const { handleUploadFile, isUploading, removeFile, files, clearFiles } =
    useUploadFile();

  const { send, answer, done } = useSendMessageWithSse(
    api.completeConversation,
  );
  const {
    scrollRef,
    messageContainerRef,
    derivedMessages,
    addNewestAnswer,
    addNewestQuestion,
    removeLatestMessage,
    removeMessageById,
    removeMessagesAfterCurrentMessage,
    setDerivedMessages,
  } = useSelectNextMessages();

  const sendMessage = useCallback(
    async ({
      message,
      currentConversationId,
      messages,
      enableInternet,
      enableThinking,
    }: {
      message: IMessage;
      currentConversationId?: string;
      messages?: IMessage[];
    } & NextMessageInputOnPressEnterParameter) => {
      const res = await send(
        {
          conversation_id: currentConversationId ?? conversationId,
          messages: [
            ...(Array.isArray(messages) && messages?.length > 0
              ? messages
              : (derivedMessages ?? [])),
            message,
          ],
          reasoning: enableThinking,
          internet: enableInternet,
        },
        controller,
      );

      if (res && (res?.response.status !== 200 || res?.data?.code !== 0)) {
        // cancel loading
        setValue(message.content);
        console.info('removeLatestMessage111');
        removeLatestMessage();
      }
    },
    [
      derivedMessages,
      conversationId,
      removeLatestMessage,
      setValue,
      send,
      controller,
    ],
  );

  const { regenerateMessage } = useRegenerateMessage({
    removeMessagesAfterCurrentMessage,
    sendMessage,
    messages: derivedMessages,
  });

  const { createConversationBeforeSendMessage } =
    useCreateConversationBeforeSendMessage();

  const handlePressEnter = useCallback(
    async ({
      enableThinking,
      enableInternet,
    }: NextMessageInputOnPressEnterParameter) => {
      const userQuestion = value.trim();

      if (trim(userQuestion) === '') return;

      const imageFile = rawFiles.find(isImageFile);
      let finalContent = userQuestion;

      if (imageFile) {
        try {
          const visionText = await image2text(imageFile);
          finalContent = buildImageRagQuestion(visionText, userQuestion);
        } catch (error) {
          console.error('Image2Text failed:', error);
          return;
        }
      }

      const data = await createConversationBeforeSendMessage(userQuestion);

      if (data === undefined) {
        return;
      }

      const { targetConversationId, currentMessages } = data;

      const id = uuid();

      addNewestQuestion({
        content: userQuestion,
        files: files,
        id,
        role: MessageType.User,
        conversationId: targetConversationId,
      });

      if (done) {
        setValue('');
        sendMessage({
          currentConversationId: targetConversationId,
          messages: currentMessages,
          message: {
            id,
            content: finalContent,
            role: MessageType.User,
            files: files,
            conversationId: targetConversationId,
          },
          enableInternet,
          enableThinking,
        });
      }
      clearFiles();
      setRawFiles([]);
    },
    [
      value,
      rawFiles,
      image2text,
      createConversationBeforeSendMessage,
      addNewestQuestion,
      files,
      done,
      clearFiles,
      setValue,
      sendMessage,
    ],
  );

  useEffect(() => {
    //  #1289
    if (answer.answer && conversationId && isNew !== 'true') {
      addNewestAnswer(answer);
    }
  }, [answer, addNewestAnswer, conversationId, isNew]);

  return {
    handlePressEnter,
    handleInputChange,
    value,
    setValue,
    regenerateMessage,
    sendLoading: !done,
    scrollRef,
    messageContainerRef,
    derivedMessages,
    removeMessageById,
    handleUploadFile,
    isUploading,
    removeFile,
    setDerivedMessages,
    setRawFiles,
    image2textLoading,
  };
};
