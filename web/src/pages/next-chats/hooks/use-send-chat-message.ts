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
import { useImage2Text } from './use-image2text';
import { useFindPrologueFromDialogList } from './use-select-conversation-list';
import { useUploadFile } from './use-upload-file';

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
      image2text_context,
    }: {
      message: IMessage;
      currentConversationId?: string;
      messages?: IMessage[];
      image2text_context?: string;
    } & NextMessageInputOnPressEnterParameter) => {
      const body: Record<string, any> = {
        conversation_id: currentConversationId ?? conversationId,
        messages: [
          ...(Array.isArray(messages) && messages?.length > 0
            ? messages
            : (derivedMessages ?? [])),
          message,
        ],
        reasoning: enableThinking,
        internet: enableInternet,
      };
      if (image2text_context) {
        body.image2text_context = image2text_context;
      }
      const res = await send(body, controller);

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
      let visionText: string | undefined;

      if (imageFile) {
        try {
          visionText = await image2text(imageFile);
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
        files: [...files, ...rawFiles.filter(isImageFile)],
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
            content: userQuestion,
            role: MessageType.User,
            files: files,
            conversationId: targetConversationId,
          },
          enableInternet,
          enableThinking,
          image2text_context: visionText,
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
